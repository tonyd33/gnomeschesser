import chess/evaluate
import chess/evaluate/common
import chess/evaluate/psqt
import chess/game
import chess/move
import chess/piece
import chess/search/evaluation.{type Evaluation, Evaluation}
import chess/search/game_history
import chess/search/search_state.{type SearchState, type SearchStats}
import chess/search/transposition
import gleam/bool
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam_community/maths
import util/interruptable_state.{type InterruptableState} as interruptable
import util/order_addons
import util/state
import util/xint.{type ExtendedInt}

/// There's no possible way we should ever be searching past this depth in
/// a proper search.
/// We have a soft limit in the case where our search yields that a draw
/// is the best outcome.
///
const soft_max_depth = 99

pub type SearchOpts {
  SearchOpts(max_depth: Option(Int))
}

pub const default_search_opts = SearchOpts(max_depth: None)

pub fn checkpointed_iterative_deepening(
  game: game.Game,
  current_depth: evaluation.Depth,
  opts: SearchOpts,
  game_history: game_history.GameHistory,
  checkpoint_hook: fn(SearchStats, evaluation.Depth, Evaluation) -> Nil,
) -> InterruptableState(SearchState, Evaluation) {
  use best_evaluation: Evaluation <- interruptable.do({
    use <- interruptable.interruptable
    use <- interruptable.discard(
      interruptable.from_state(search_state.stats_set_iteration_depth(
        current_depth,
      )),
    )
    let game_hash = game.hash(game)
    use cached_evaluation <- interruptable.do(
      interruptable.from_state(search_state.transposition_get(game_hash)),
    )
    // perform the search at each depth, the negamax function will handle sorting and caching
    use best_evaluation <- interruptable.map(case cached_evaluation {
      Ok(entry) -> {
        let offset = 10 |> xint.from_int
        search_with_widening_windows(
          game,
          current_depth,
          entry.eval.score |> xint.subtract(offset),
          entry.eval.score |> xint.add(offset),
          0,
          game_history,
        )
      }
      Error(Nil) ->
        search_with_widening_windows(
          game,
          current_depth,
          xint.NegInf,
          xint.PosInf,
          0,
          game_history,
        )
    })

    // a janky way of selecting a random move if we don't have a best move
    // this can currently happen if there's a forced checkmate scenario
    case best_evaluation.best_move {
      Some(_) -> best_evaluation
      None -> {
        let valid_moves =
          game.valid_moves(game)
          |> list.shuffle()
        // get a random move if we are in checkmate
        let random_move = valid_moves |> list.first |> option.from_result
        Evaluation(..best_evaluation, best_move: random_move)
      }
    }
  })

  use <- interruptable.checkpoint(best_evaluation)
  use <- interruptable.discard({
    use search_state: SearchState <- interruptable.select
    checkpoint_hook(search_state.stats, current_depth, best_evaluation)
  })

  let max_depth = option.unwrap(opts.max_depth, soft_max_depth)
  case current_depth >= max_depth {
    True -> interruptable.return(best_evaluation)
    False ->
      case best_evaluation.score {
        // terminate the search if we detect we're in mate
        xint.PosInf | xint.NegInf -> interruptable.return(best_evaluation)
        _ ->
          checkpointed_iterative_deepening(
            game,
            current_depth + 1,
            opts,
            game_history,
            checkpoint_hook,
          )
      }
  }
}

/// Calls negamax_alphabeta_failsoft with wider and wider windows
/// until we get a PV node
///
pub fn search_with_widening_windows(
  game: game.Game,
  depth: evaluation.Depth,
  alpha: ExtendedInt,
  beta: ExtendedInt,
  attempts: Int,
  game_history: game_history.GameHistory,
) -> InterruptableState(SearchState, Evaluation) {
  use best_evaluation <- interruptable.do(
    negamax_alphabeta_failsoft(game, depth, alpha, beta, game_history, []),
  )
  case best_evaluation.score, best_evaluation.node_type {
    // if it's +/- Inf means it's already hit the highest bound
    // It's a forced checkmate in every branch
    // no point in searching more
    _, evaluation.PV | xint.PosInf, _ | xint.NegInf, _ ->
      interruptable.return(best_evaluation)
    // Otherwise we call the search again with wider windows
    // The narrower the window is, the more branches are pruned
    // but if our score is not inside the window, then we're forced to re-search
    score, evaluation.All -> {
      search_with_widening_windows(
        game,
        depth,
        score |> xint.subtract(10 + attempts * 100 |> xint.from_int),
        beta,
        attempts + 1,
        game_history,
      )
    }
    score, evaluation.Cut -> {
      search_with_widening_windows(
        game,
        depth,
        alpha,
        score |> xint.add(10 + attempts * 100 |> xint.from_int),
        attempts + 1,
        game_history,
      )
    }
  }
}

/// Don't even bother inserting into or looking up from the transposition
/// table unless we're past this depth!
///
const tt_min_leaf_distance = 1

/// https://www.chessprogramming.org/Alpha-Beta#Negamax_Framework
/// returns the score of the current game searched at depth
/// uses negamax version of alpha beta pruning with failsoft
/// scores are from the perspective of the active player
/// If white's turn, +1 is white's advantage
/// If black's turn, +1 is black's advantage
/// alpha is the "best" score for active player
/// beta is the "best" score for non-active player
///
fn negamax_alphabeta_failsoft(
  game: game.Game,
  depth: evaluation.Depth,
  alpha: ExtendedInt,
  beta: ExtendedInt,
  game_history: game_history.GameHistory,
  score_history: List(Option(ExtendedInt)),
) -> InterruptableState(SearchState, Evaluation) {
  use <- interruptable.interruptable

  let game_hash = game.hash(game)

  use <- bool.guard(
    // 3 fold repetition:
    // If we've encountered this position before, we can assume we're in a 3 fold loop
    // and that this position will resolve to a 0
    game_history.is_previous_game(game_history, game)
      // 50 moves rule:
      // If 50 moves have passed without any captures, then the position is a draw.
      || game.halfmove_clock(game) >= 100
      // Insufficient material:
      // If there isn't enough material to mate, consider this position a draw.
      || game.is_insufficient_material(game),
    interruptable.return(Evaluation(
      score: xint.from_int(0),
      node_type: evaluation.PV,
      best_move: None,
    )),
  )

  // return early if we find an entry in the transposition table
  use cached_evaluation <- interruptable.do({
    use <- bool.guard(
      depth < tt_min_leaf_distance,
      interruptable.return(Error(Nil)),
    )

    search_state.transposition_get(game_hash)
    |> interruptable.from_state
    |> interruptable.map(fn(x) {
      use transposition.Entry(cached_depth, evaluation, _) <- result.try(x)
      use <- bool.guard(cached_depth < depth, Error(Nil))
      // If we find a cached entry that is deeper than our current search
      case evaluation {
        Evaluation(node_type: evaluation.PV, ..) -> Ok(evaluation)
        Evaluation(score:, node_type: evaluation.Cut, ..) ->
          case xint.gte(score, beta) {
            True -> Ok(evaluation)
            False -> Error(Nil)
          }
        Evaluation(score:, node_type: evaluation.All, ..) ->
          case xint.lte(score, alpha) {
            True -> Ok(evaluation)
            False -> Error(Nil)
          }
      }
    })
  })
  use <- result.lazy_unwrap(result.map(cached_evaluation, interruptable.return))

  // Otherwise, actually do negamax
  use evaluation <- interruptable.do({
    do_negamax_alphabeta_failsoft(
      game,
      depth,
      alpha,
      beta,
      game_history,
      score_history,
    )
  })

  // Manage stats and transposition table before returning evaluation.
  use <- interruptable.discard(
    interruptable.from_state(search_state.stats_increment_nodes_searched()),
  )
  use <- interruptable.discard(
    interruptable.from_state(case depth >= tt_min_leaf_distance {
      True -> search_state.transposition_insert(game_hash, #(depth, evaluation))
      False -> state.return(Nil)
    }),
  )

  interruptable.return(evaluation)
}

fn do_negamax_alphabeta_failsoft(
  game: game.Game,
  depth: evaluation.Depth,
  alpha: ExtendedInt,
  beta: ExtendedInt,
  game_history: game_history.GameHistory,
  score_history: List(Option(ExtendedInt)),
) -> InterruptableState(SearchState, Evaluation) {
  use <- bool.lazy_guard(depth <= 0, fn() {
    use score <- interruptable.map(quiesce(game, alpha, beta))
    Evaluation(score:, node_type: evaluation.PV, best_move: None)
  })
  let is_check = game.is_check(game, game.turn(game))

  let static_evaluation =
    evaluate.game(game)
    |> xint.multiply(evaluate.player(game.turn(game)) |> xint.from_int)

  let safe_score = case is_check {
    True -> None
    False -> Some(static_evaluation)
  }

  let improving = {
    // Not improving if we're in check
    use <- bool.guard(is_check, False)

    case score_history {
      [_, Some(score_2_ply_ago), ..] ->
        xint.gt(static_evaluation, score_2_ply_ago)
      [_, _, _, Some(score_4_ply_ago), ..] ->
        xint.gt(static_evaluation, score_4_ply_ago)
      _ -> False
    }
  }

  use rfp_evaluation <- interruptable.do({
    let should_do_rfp = depth > 1 && !is_check
    use <- bool.guard(!should_do_rfp, interruptable.return(Error(Nil)))

    // TODO: Tweak margin
    let margin =
      50
      * {
        depth
        - case improving {
          True -> 1
          False -> 0
        }
      }

    case xint.gte(static_evaluation, xint.add(beta, xint.from_int(margin))) {
      True -> {
        use <- interruptable.discard(
          interruptable.from_state(search_state.stats_add_rfp_cutoffs(depth, 1)),
        )
        interruptable.return(
          Ok(Evaluation(
            score: static_evaluation,
            best_move: None,
            node_type: evaluation.Cut,
          )),
        )
      }
      False -> interruptable.return(Error(Nil))
    }
  })
  use <- result.lazy_unwrap(result.map(rfp_evaluation, interruptable.return))

  // Null move pruning/null move reduction: if a null move was made (i.e. we
  // pass the turn) yet we caused a beta cutoff, we can be pretty sure that
  // any legal move would cause a beta cutoff, so we'll return a cutoff early.
  // https://www.chessprogramming.org/Null_Move_Pruning
  //
  // In endgames, however, it may actually be advantageous to make null moves
  // (called zugzwang positions).
  // In that case, we do null move reductions instead: instead of returning
  // early, we continue searching at a reduced depth, which makes us less
  // vulnerable to zugzwangs.
  // https://www.chessprogramming.org/Null_Move_Reductions
  use null_evaluation <- interruptable.do({
    let should_do_nmp = !is_check
    use <- bool.guard(!should_do_nmp, interruptable.return(Error(Nil)))

    let r = 4
    use evaluation <- interruptable.do(
      negamax_alphabeta_failsoft(
        game.reverse_turn(game),
        depth - 1 - r,
        xint.negate(beta),
        xint.negate(xint.subtract(beta, xint.from_int(1))),
        game_history.insert(game_history, game),
        [safe_score, ..score_history],
      )
      |> interruptable.map(evaluation.negate),
    )

    let margin = case improving {
      True -> 50
      False -> 0
    }

    case xint.gte(evaluation.score, xint.add(beta, xint.from_int(margin))) {
      True -> {
        use <- interruptable.discard(
          interruptable.from_state(search_state.stats_add_nmp_cutoffs(depth, 1)),
        )
        interruptable.return(Ok(
          Evaluation(..evaluation, node_type: evaluation.Cut),
        ))
      }
      False -> {
        interruptable.return(Error(Nil))
      }
    }
  })
  // The intended flow control is:
  // - If we have a null evaluation that caused a beta-cutoff and we're not in
  //   endgame, return early (NMP)
  // - If we have a null evaluation that caused a beta-cutoff and we're in
  //   endgame, reduce depth by some amount (NMR)
  // - Otherwise, continue as usual
  use <- result.lazy_unwrap(result.map(
    // Disable NMP during "endgame". This is not accurate, but doing a phase
    // calculation like we do in evaluation is expensive: it requires us to
    // do an entire iteration over the pieces.
    // TODO: See if we can get a non-expensive endgame check and give more
    // specific conditions so we can do more NMPs
    case game.fullmove_number(game) < 28 {
      True -> null_evaluation
      False -> Error(Nil)
    },
    interruptable.return,
  ))
  let depth = case null_evaluation {
    Ok(_) -> depth - 4
    Error(Nil) -> depth
  }
  // We may need to evaluate now that we reduced depth. Do another check.
  use <- bool.lazy_guard(depth <= 0, fn() {
    use score <- interruptable.map(quiesce(game, alpha, beta))
    Evaluation(score:, node_type: evaluation.PV, best_move: None)
  })

  use #(moves, nmoves) <- interruptable.do(sorted_moves(
    game,
    depth,
    alpha,
    beta,
    game_history,
  ))

  use <- bool.lazy_guard(nmoves == 0, fn() {
    // if checkmate/stalemate
    let score = case is_check {
      True -> xint.NegInf
      False -> xint.Finite(0)
    }
    Evaluation(score:, node_type: evaluation.PV, best_move: None)
    |> interruptable.return
  })

  // We iterate through every move and perform minimax to evaluate said move
  // accumulator keeps track of best evaluation while updating the node type
  {
    use #(best_evaluation, alpha, move_number), move <- interruptable.list_fold_until_s(
      moves,
      #(Evaluation(xint.NegInf, evaluation.PV, None), alpha, 0),
    )

    let lmr_depth_reduction = {
      // Late move reduction (LMR).
      // Do not reduce if:
      // - we're currently in check, or
      // - depth < 3, or
      // - we're searching the first few moves
      use <- bool.guard(is_check || depth < 3 || move_number < 3, 0)

      // Base formula from Weiss
      // c + (ln(depth) * ln(move_number))/d
      // https://www.chessprogramming.org/Late_Move_Reductions#Reduction_Depth
      let #(c, d) = case
        move.is_capture(move) || move.is_promotion(move),
        improving
      {
        // Reduce captures/promotions less
        // Original Weiss values were:
        // #(0.2, 3.35)
        True, _ -> #(0.1, 6.7)
        // Reduce quiet moves more
        // Original Weiss values were:
        // #(1.35, 2.75)
        False, True -> #(0.4, 3.1)
        // Reduce quiet moves that aren't improving even more
        False, False -> #(0.45, 3.0)
      }
      let assert Ok(ln_depth) = maths.natural_logarithm(int.to_float(depth))
      let assert Ok(ln_move_number) =
        maths.natural_logarithm(int.to_float(move_number))
      float.round(c +. { { ln_depth *. ln_move_number } /. d })
    }

    // Currently we only have one factor contributing to any depth reductions,
    // but this is subject to change if we add null move reductions (NMR).
    let depth_reduction = lmr_depth_reduction

    let go = fn(e1: Evaluation, depth, alpha, beta) -> InterruptableState(
      SearchState,
      #(Evaluation, ExtendedInt),
    ) {
      use e2 <- interruptable.do({
        use neg_evaluation <- interruptable.map(
          negamax_alphabeta_failsoft(
            game.apply(game, move),
            depth,
            xint.negate(beta),
            xint.negate(alpha),
            game_history.insert(game_history, game),
            [safe_score, ..score_history],
          ),
        )
        Evaluation(..evaluation.negate(neg_evaluation), best_move: Some(move))
      })

      interruptable.return(#(
        case xint.gt(e2.score, e1.score) {
          True -> e2
          False -> e1
        },
        xint.max(alpha, e2.score),
      ))
    }

    let finish = fn(e: Evaluation, alpha, beta) {
      // beta-cutoff
      case xint.gte(e.score, beta) {
        True -> {
          let new_e = Evaluation(..e, node_type: evaluation.Cut)
          let move_context = move.get_context(move)

          use <- interruptable.discard(
            case move_context.capture |> option.is_none {
              True -> {
                // non-capture moves update the history table
                let to = move.get_to(move)
                let piece = move_context.piece
                interruptable.from_state(search_state.history_update(
                  #(to, piece),
                  depth * depth,
                ))
              }
              False -> interruptable.return(Nil)
            },
          )
          use <- interruptable.discard(
            interruptable.from_state(search_state.stats_add_beta_cutoffs(
              depth,
              nmoves - move_number + 1,
            )),
          )
          #(new_e, alpha, move_number + 1) |> list.Stop |> interruptable.return
        }
        False ->
          #(e, alpha, move_number + 1)
          |> list.Continue
          |> interruptable.return
      }
    }

    // Try to do a reduced search to see if it causes a beta-cutoff.
    use #(tentative_evaluation, tentative_alpha) <- interruptable.do(go(
      best_evaluation,
      depth - 1 - depth_reduction,
      alpha,
      beta,
    ))

    case xint.gte(tentative_evaluation.score, beta), depth_reduction > 0 {
      // The search on the child node caused a beta-cutoff while reducing the
      // depth. We have to retry the search at the proper depth.
      True, True -> {
        // use <- interruptable.discard(
        //   interruptable.from_state(
        //     search_state.stats_increment_lmr_verifications(depth),
        //   ),
        // )
        use #(best_evaluation, alpha) <- interruptable.do(go(
          best_evaluation,
          depth - 1,
          alpha,
          beta,
        ))
        finish(best_evaluation, alpha, beta)
      }
      // If it didn't even cause a beta-cutoff, then continue as usual.
      _, _ -> {
        // use <- interruptable.discard(case depth_reduction > 0 {
        //   True ->
        //     interruptable.from_state(search_state.stats_increment_lmrs(depth))
        //   False -> interruptable.return(Nil)
        // })
        finish(tentative_evaluation, tentative_alpha, beta)
      }
    }
  }
  |> interruptable.map(fn(x) { x.0 })
}

/// returns the score of the current game while checking
/// every capture and check
/// scores are from the perspective of the active player
/// If white's turn, +1 is white's advantage
/// If black's turn, +1 is black's advantage
/// alpha is the "best" score for active player
/// beta is the "best" score for non-active player
///
fn quiesce(
  game: game.Game,
  alpha: ExtendedInt,
  beta: ExtendedInt,
) -> InterruptableState(SearchState, ExtendedInt) {
  use <- interruptable.interruptable
  let score =
    evaluate.game(game)
    |> xint.multiply({ evaluate.player(game.turn(game)) |> xint.from_int })

  use <- bool.guard(xint.gte(score, beta), interruptable.return(score))

  let alpha = xint.max(alpha, score)

  let compare_mvv_lva = order_addons.or(compare_mvv, compare_lva)

  let moves = list.sort(game.valid_moves(game), compare_mvv_lva)
  {
    use #(best_score, alpha), move <- interruptable.list_fold_until_s(moves, #(
      score,
      alpha,
    ))

    // If game isn't capture, continue
    use <- bool.guard(
      move.is_quiet(move),
      interruptable.return(list.Continue(#(best_score, alpha))),
    )

    use score <- interruptable.do(interruptable.map(
      quiesce(game.apply(game, move), xint.negate(beta), xint.negate(alpha)),
      xint.negate,
    ))

    use <- bool.guard(
      xint.gte(score, beta),
      interruptable.return(list.Stop(#(score, alpha))),
    )

    interruptable.return(
      list.Continue(#(xint.max(best_score, score), xint.max(alpha, score))),
    )
  }
  |> interruptable.map(fn(x) { x.0 })
}

/// [Iteratively deepen](https://www.chessprogramming.org/Iterative_Deepening)
/// on this node.
///
pub fn iteratively_deepen(
  game: game.Game,
  current_depth: evaluation.Depth,
  alpha: ExtendedInt,
  beta: ExtendedInt,
  opts: SearchOpts,
  game_history: game_history.GameHistory,
) {
  use evaluation <- interruptable.do(
    negamax_alphabeta_failsoft(
      game,
      current_depth,
      alpha,
      beta,
      game_history,
      [],
    ),
  )
  case opts.max_depth {
    Some(max_depth) if current_depth >= max_depth ->
      interruptable.return(evaluation)
    _ ->
      iteratively_deepen(
        game,
        current_depth + 1,
        alpha,
        beta,
        opts,
        game_history,
      )
  }
}

/// If we miss the cache trying to get the PV move for move ordering, we'll
/// (internally) iteratively deepen to find a PV move. This is how far we'll
/// deepen.
///
const iid_depth = 4

/// Internal iterative deepening is not always a benefit even if we miss the
/// cache. We want to be selective about when we deepen: if we're close to the
/// leaf of the tree and we iteratively deepen past the leaf, we'd essentially
/// just be searching to a higher depth anyway!
///
/// Thus we want to iteratively deepen if we're far from the leaves, making
/// sure not to deepen past the leaf.
///
/// This number represents the minimum distance from the leaves to trigger
/// an IID upon cache miss. To not deepen past the leaf, this number should
/// always be quite a bit greater than `iid_depth`.
///
const iid_min_leaf_distance = 9

/// Get the PV move for a game, trying to hit the cache and falling back to
/// (internally) iteratively deepening if we're far from the leaves.
///
/// `depth` should represent the distance from the leaves.
///
fn get_pv_move(game: game.Game, depth: evaluation.Depth, alpha, beta, history) {
  use cached_entry <- interruptable.do(
    interruptable.from_state(search_state.transposition_get(game.hash(game))),
  )
  case cached_entry, depth >= iid_min_leaf_distance {
    // We hit the cache. No need to for IID at all, just return the PV move.
    Ok(transposition.Entry(eval:, ..)), _ ->
      interruptable.return(eval.best_move)
    // We missed the cache and we're far from the leaves. So we should
    // iteratively deepen for the PV move.
    Error(Nil), True -> {
      use eval <- interruptable.do(iteratively_deepen(
        game,
        1,
        alpha,
        beta,
        SearchOpts(max_depth: Some(iid_depth)),
        history,
      ))
      use <- interruptable.discard(
        interruptable.from_state(search_state.stats_increment_iid_triggers(
          depth,
        )),
      )
      interruptable.return(eval.best_move)
    }
    // Cache miss but we're close to the leaves. Too bad.
    Error(Nil), False -> interruptable.return(None)
  }
}

/// Sort moves from best to worse, which improves alphabeta pruning.
/// Also returns the number of moves, which is free because we must iterate
/// over the moves anyway, and is added here purely for optimization.
///
fn sorted_moves(
  game: game.Game,
  depth: evaluation.Depth,
  alpha,
  beta,
  history,
) -> InterruptableState(
  SearchState,
  #(List(move.Move(move.ValidInContext)), Int),
) {
  use best_move <- interruptable.do(get_pv_move(
    game,
    depth,
    alpha,
    beta,
    history,
  ))

  // retrieve the cached transposition table data
  let valid_moves = game.valid_moves(game)

  let #(best_move, capture_promotion_moves, quiet_moves, nmoves) =
    list.fold(valid_moves, #(None, [], [], 0), fn(acc, move) {
      // TODO: also count checking moves?
      let #(best, capture_promotions, quiet, nmoves) = acc

      // If this is the best move, just return
      use <- bool.guard(
        option.map(best_move, move.equal(_, move)) |> option.unwrap(False),
        #(Some(move), capture_promotions, quiet, nmoves + 1),
      )

      // non-quiet moves (captures and promotions get sorted next)
      let move_context = move.get_context(move)
      let is_quiet =
        option.is_none(move_context.capture)
        && option.is_none(move.get_promotion(move))
      case is_quiet {
        True -> #(best, capture_promotions, [move, ..quiet], nmoves + 1)
        False -> #(best, [move, ..capture_promotions], quiet, nmoves + 1)
      }
    })
  // TODO: Ideally, use real phase calculations
  let phase = case game.fullmove_number(game) > 25 {
    True -> common.EndGame
    False -> common.MidGame
  }
  let compare_psqt = compare_psqt(phase)
  let compare_psqt_delta = compare_psqt_delta(phase)

  // Compare a move by the PSQ score they land on.

  // We use MVV-LVA for sorting capture_promotion moves:
  // We sort most valuable victim, most valuable first, falling back to
  // sorting by least valuable attacker, least valuable first.
  // For promotions, we count it as the promoted piece
  let compare_mvv_lva =
    order_addons.or(compare_mvv, compare_lva)
    |> order_addons.or(compare_psqt)
    |> order_addons.or(compare_psqt_delta)
  let capture_promotion_moves =
    list.sort(capture_promotion_moves, compare_mvv_lva)

  use compare_quiet_history <- interruptable.map({
    use search_state: SearchState <- interruptable.select
    compare_quiet_history(search_state.history)
  })

  let compare_quiet_moves =
    order_addons.or(compare_quiet_history, compare_psqt)
    |> order_addons.or(compare_psqt_delta)
  let quiet_moves = list.sort(quiet_moves, compare_quiet_moves)

  let non_best_move = list.append(capture_promotion_moves, quiet_moves)

  let sorted_moves =
    option.map(best_move, fn(best_move) { [best_move, ..non_best_move] })
    |> option.unwrap(non_best_move)
  #(sorted_moves, nmoves)
}

fn compare_mvv(move1, move2) {
  case move.get_context(move1).capture, move.get_context(move2).capture {
    Some(#(_, piece.Piece(_, a))), Some(#(_, piece.Piece(_, b))) ->
      int.compare(evaluate.piece_symbol(b), evaluate.piece_symbol(a))
    Some(_), _ -> order.Lt
    _, Some(_) -> order.Gt
    _, _ -> order.Eq
  }
}

fn compare_quiet_history(history) {
  fn(move1, move2) {
    let key1 = #(move.get_to(move1), move.get_context(move1).piece)
    let key2 = #(move.get_to(move2), move.get_context(move2).piece)
    let history1 = dict.get(history, key1) |> result.unwrap(0)
    let history2 = dict.get(history, key2) |> result.unwrap(0)
    // bigger history should go first
    int.compare(history2, history1)
  }
}

fn compare_lva(move1, move2) {
  let piece1 = move.get_context(move1).piece.symbol
  let piece1 =
    move.get_promotion(move1)
    |> option.unwrap(piece1)
  let piece2 = move.get_context(move2).piece.symbol
  let piece2 =
    move.get_promotion(move2)
    |> option.unwrap(piece2)
  int.compare(evaluate.piece_symbol(piece1), evaluate.piece_symbol(piece2))
}

/// Compare a move by the PSQ score of the square the piece lands on, highest
/// first.
///
fn compare_psqt(phase) {
  fn(move1, move2) {
    let score1 =
      psqt.raw_score(move.get_context(move1).piece, move.get_to(move1), phase)
    let score2 =
      psqt.raw_score(move.get_context(move2).piece, move.get_to(move2), phase)

    int.compare(score2, score1)
  }
}

/// Compare a move by the different in PSQ scores from where they were and
/// where they land to, with the highest delta first.
///
fn compare_psqt_delta(phase) {
  fn(move1, move2) {
    let score_to1 =
      psqt.raw_score(move.get_context(move1).piece, move.get_to(move1), phase)
    let score_from1 =
      psqt.raw_score(move.get_context(move1).piece, move.get_from(move1), phase)
    let delta1 = score_to1 - score_from1

    let score_to2 =
      psqt.raw_score(move.get_context(move2).piece, move.get_to(move2), phase)
    let score_from2 =
      psqt.raw_score(move.get_context(move2).piece, move.get_from(move2), phase)
    let delta2 = score_to2 - score_from2

    int.compare(delta2, delta1)
  }
}
