import chess/evaluate
import chess/game
import chess/move
import chess/piece
import chess/search/evaluation.{type Evaluation, Evaluation}
import chess/search/game_history
import chess/search/search_state.{type SearchState}
import chess/search/transposition
import gleam/bool
import gleam/dict
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/result
import gleam/time/duration
import gleam/time/timestamp
import util/order_addons
import util/state.{type State, State}
import util/xint.{type ExtendedInt}

/// We don't let the transposition table get bigger than this
const max_tt_size = 100_000

/// When pruning the transposition table, how recent of entries do we decide to
/// keep? In ms
const max_tt_recency = 50_000

pub type SearchMessage {
  SearchStateUpdate(search_state: SearchState)
  SearchUpdate(
    best_evaluation: Evaluation,
    game: game.Game,
    depth: Int,
    time: Int,
    nodes_searched: Int,
    nps: Int,
    hashfull: Int,
  )
  SearchDone
}

pub type SearchOpts {
  SearchOpts(max_depth: Option(Int))
}

pub const default_search_opts = SearchOpts(max_depth: None)

pub fn new(
  game: game.Game,
  search_state: SearchState,
  search_subject: process.Subject(SearchMessage),
  opts: SearchOpts,
  game_history: game_history.GameHistory,
) -> process.Pid {
  process.start(
    fn() {
      {
        let now = timestamp.system_time()
        use <- state.discard(search_state.stats_zero(now))
        search(search_subject, game, 1, opts, game_history)
      }
      |> state.go(initial: search_state)
    },
    True,
  )
}

fn search(
  search_subject: process.Subject(SearchMessage),
  game: game.Game,
  current_depth: evaluation.Depth,
  opts: SearchOpts,
  game_history: game_history.GameHistory,
) -> State(SearchState, Nil) {
  let game_hash = game.hash(game)
  use cached_evaluation <- state.do(search_state.transposition_get(game_hash))

  // perform the search at each depth, the negamax function will handle sorting and caching
  use best_evaluation <- state.do(case cached_evaluation {
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
  let best_evaluation = case best_evaluation.best_move {
    Some(_) -> best_evaluation
    None -> {
      let valid_moves =
        game.valid_moves(game)
        |> list.shuffle()
      // get a random move if we are in checkmate
      let random_move = valid_moves |> list.first |> option.from_result
      Evaluation(
        ..best_evaluation,
        best_move: random_move,
        best_line: [random_move]
          |> option.values,
      )
    }
  }

  use search_state: SearchState <- state.do(state.get_state())
  let now = timestamp.system_time()
  let dt =
    timestamp.difference(search_state.stats.init_time, now)
    |> duration.to_seconds
    |> float.multiply(1000.0)
    |> float.round
  use nps <- state.do(
    state.select(search_state.stats_nodes_per_second(_, now))
    |> state.map(float.round),
  )

  // TODO: use a logging library for this?
  // use info <- state.do(
  //   search_state.stats_to_string(_, now)
  //   |> state.select,
  // )
  // io.print_error(info)

  // Send the search update first! Doing it in the other order with large
  // large transposition tables may be slow enough to miss a deadline.
  process.send(
    search_subject,
    SearchUpdate(
      best_evaluation:,
      game:,
      depth: current_depth,
      time: dt,
      nodes_searched: search_state.stats.nodes_searched,
      nps:,
      hashfull: dict.size(search_state.transposition) * 1000 / max_tt_size,
    ),
  )
  process.send(search_subject, SearchStateUpdate(search_state:))

  case opts.max_depth {
    Some(max_depth) if current_depth >= max_depth -> {
      process.send(search_subject, SearchDone)
      state.return(Nil)
    }
    _ ->
      case best_evaluation.score {
        // terminate the search if we detect we're in mate
        xint.PosInf | xint.NegInf -> state.return(Nil)
        _ -> search(search_subject, game, current_depth + 1, opts, game_history)
      }
  }
}

/// Calls negamax_alphabeta_failsoft with wider and wider windows
/// until we get a PV node
fn search_with_widening_windows(
  game: game.Game,
  depth: evaluation.Depth,
  alpha: ExtendedInt,
  beta: ExtendedInt,
  attempts: Int,
  game_history: game_history.GameHistory,
) -> State(SearchState, Evaluation) {
  use best_evaluation <- state.do(negamax_alphabeta_failsoft(
    game,
    depth,
    alpha,
    beta,
    game_history,
  ))
  case best_evaluation.score, best_evaluation.node_type {
    // if it's +/- Inf means it's already hit the highest bound
    // It's a forced checkmate in every branch
    // no point in searching more
    _, evaluation.PV | xint.PosInf, _ | xint.NegInf, _ ->
      state.return(best_evaluation)
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

/// Don't even bother inserting into the transposition table unless we're past
/// this depth!
///
/// TODO: Tune this later
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
) -> State(SearchState, Evaluation) {
  let game_hash = game.hash(game)

  use <- bool.guard(
    // 3 fold repetition:
    // If we've encountered this position before, we can assume we're in a 3 fold loop
    // and that this position will resolve to a 0
    game_history.is_previous_game(game_history, game)
      // 50 moves rule:
      // If 50 moves have passed without any captures, then the position is a draw.
      || game.halfmove_clock(game) >= 100,
    state.return(
      Evaluation(
        score: xint.from_int(0),
        node_type: evaluation.PV,
        best_move: None,
        best_line: [],
      ),
    ),
  )

  // return early if we find an entry in the transposition table
  use cached_evaluation <- state.do({
    use <- bool.guard(depth < tt_min_leaf_distance, state.return(Error(Nil)))

    search_state.transposition_get(game_hash)
    |> state.map(fn(x) {
      use transposition.Entry(cached_depth, evaluation, _) <- result.try(x)
      use <- bool.guard(cached_depth < depth, Error(Nil))
      // If we find a cached entry that is deeper than our current search
      case evaluation {
        Evaluation(_, evaluation.PV, _, _) -> Ok(evaluation)
        Evaluation(score, evaluation.Cut, _, _) ->
          case xint.gte(score, beta) {
            True -> Ok(evaluation)
            False -> Error(Nil)
          }
        Evaluation(score, evaluation.All, _, _) ->
          case xint.lte(score, alpha) {
            True -> Ok(evaluation)
            False -> Error(Nil)
          }
      }
    })
  })
  use <- result.lazy_unwrap(result.map(cached_evaluation, state.return))

  // Otherwise, actually do negamax
  use evaluation <- state.do({
    do_negamax_alphabeta_failsoft(game, depth, alpha, beta, game_history)
  })

  // Manage stats and transposition table before returning evaluation.
  use <- state.discard(search_state.stats_increment_nodes_searched())
  use <- state.discard(case depth >= tt_min_leaf_distance {
    True -> {
      use <- state.discard(
        search_state.transposition_insert(game_hash, #(depth, evaluation)),
      )
      use <- state.discard(search_state.transposition_prune(
        when: search_state.LargerThan(max_tt_size),
        do: search_state.ByRecency(max_tt_recency),
      ))

      state.return(Nil)
    }
    False -> state.return(Nil)
  })

  state.return(evaluation)
}

fn do_negamax_alphabeta_failsoft(
  game: game.Game,
  depth: evaluation.Depth,
  alpha: ExtendedInt,
  beta: ExtendedInt,
  game_history: game_history.GameHistory,
) -> State(SearchState, Evaluation) {
  use <- bool.lazy_guard(depth <= 0, fn() {
    let score = quiesce(game, alpha, beta)
    Evaluation(score:, node_type: evaluation.PV, best_move: None, best_line: [])
    |> state.return
  })

  // Null move pruning: if a null move was made (i.e. we pass the turn) yet we
  // caused a beta cutoff, we can be pretty sure that any legal move would
  // cause a beta cutoff. In such a case, return early.
  use null_evaluation <- state.do({
    // TODO: Add further conditions to avoid zugzwangs
    // TODO: Optimize so checking checks aren't expensive
    let should_do_nmp = !game.is_check(game, game.turn(game))
    use <- bool.guard(!should_do_nmp, state.return(Error(Nil)))

    let r = 4
    use evaluation <- state.map(
      negamax_alphabeta_failsoft(
        game.reverse_turn(game),
        depth - 1 - r,
        xint.negate(beta),
        xint.negate(xint.subtract(beta, xint.from_int(1))),
        game_history,
        // game_history.insert(game_history, game),
      )
      |> state.map(evaluation.negate),
    )

    case xint.gte(evaluation.score, beta) {
      True -> Ok(Evaluation(..evaluation, node_type: evaluation.Cut))
      False -> Error(Nil)
    }
  })
  use <- result.lazy_unwrap(result.map(null_evaluation, state.return))

  use #(moves, nmoves) <- state.do(sorted_moves(
    game,
    depth,
    alpha,
    beta,
    game_history,
  ))

  use <- bool.lazy_guard(nmoves == 0, fn() {
    // if checkmate/stalemate
    let score = case game.is_check(game, game.turn(game)) {
      True -> xint.NegInf
      False -> xint.Finite(0)
    }
    Evaluation(score:, node_type: evaluation.PV, best_move: None, best_line: [])
    |> state.return
  })

  // We iterate through every move and perform minimax to evaluate said move
  // accumulator keeps track of best evaluation while updating the node type
  {
    use #(best_evaluation, alpha, idx), move <- state.list_fold_until_s(
      moves,
      #(Evaluation(xint.NegInf, evaluation.PV, None, []), alpha, 0),
    )

    // TODO: Limit conditions
    let context = move.get_context(move)
    let should_reduce =
      idx > 1
      && depth > 2
      // Don't reduce on captures
      && !option.is_some(context.capture)
      // Don't reduce while "in check". This is obviously inaccurate, but
      // checking for check is expensive
      && nmoves > 4
    let depth_reduction = case should_reduce {
      True -> 1
      _ -> 0
    }

    let go = fn(e1: Evaluation, depth, alpha, beta) {
      use e2 <- state.do({
        use neg_evaluation <- state.map(negamax_alphabeta_failsoft(
          game.apply(game, move),
          depth,
          xint.negate(beta),
          xint.negate(alpha),
          game_history.insert(game_history, game),
        ))
        Evaluation(
          ..evaluation.negate(neg_evaluation),
          best_line: [move, ..neg_evaluation.best_line],
          best_move: Some(move),
        )
      })

      state.return(#(
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

          use <- state.discard(case move_context.capture |> option.is_none {
            True -> {
              // non-capture moves update the history table
              let to = move.get_to(move)
              let piece = move_context.piece
              search_state.history_update(#(to, piece), depth * depth)
            }
            False -> state.pure(Nil)
          })
          use <- state.discard(search_state.stats_add_beta_cutoffs(
            depth,
            nmoves - idx + 1,
          ))
          #(new_e, alpha, idx + 1) |> list.Stop |> state.return
        }
        False ->
          #(e, alpha, idx + 1)
          |> list.Continue
          |> state.return
      }
    }

    use #(tentative_evaluation, tentative_alpha) <- state.do(go(
      best_evaluation,
      depth - 1 - depth_reduction,
      alpha,
      beta,
    ))

    case xint.gte(tentative_evaluation.score, beta), should_reduce {
      // The search on the child node caused a beta-cutoff while reducing the
      // depth. We have to retry the search at the proper depth.
      True, True -> {
        use #(best_evaluation, alpha) <- state.do(go(
          best_evaluation,
          depth - 1,
          alpha,
          beta,
        ))
        finish(best_evaluation, alpha, beta)
      }
      _, _ -> finish(tentative_evaluation, tentative_alpha, beta)
    }
  }
  |> state.map(fn(x) { x.0 })
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
) -> ExtendedInt {
  let score =
    evaluate.game(game)
    |> xint.multiply({ evaluate.player(game.turn(game)) |> xint.from_int })

  use <- bool.guard(xint.gte(score, beta), score)
  let alpha = xint.max(alpha, score)

  let #(best_score, _) =
    game.valid_moves(game)
    |> list.fold_until(#(score, alpha), fn(acc, move) {
      let move_context = move.get_context(move)

      // If game isn't capture, continue
      use <- bool.guard(
        move_context.capture |> option.is_none,
        list.Continue(acc),
      )
      let new_game = game.apply(game, move)

      let #(best_score, alpha) = acc
      let score =
        xint.negate(quiesce(new_game, xint.negate(beta), xint.negate(alpha)))

      use <- bool.guard(xint.gte(score, beta), list.Stop(#(score, alpha)))

      list.Continue(#(xint.max(best_score, score), xint.max(alpha, score)))
    })
  best_score
}

/// [Iteratively deepen](https://www.chessprogramming.org/Iterative_Deepening)
/// on this node.
///
fn iteratively_deepen(
  game: game.Game,
  current_depth: evaluation.Depth,
  alpha: ExtendedInt,
  beta: ExtendedInt,
  opts: SearchOpts,
  game_history: game_history.GameHistory,
) {
  use evaluation <- state.do(negamax_alphabeta_failsoft(
    game,
    current_depth,
    alpha,
    beta,
    game_history,
  ))
  case opts.max_depth {
    Some(max_depth) if current_depth >= max_depth -> state.return(evaluation)
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
  use cached_entry <- state.do(search_state.transposition_get(game.hash(game)))
  case cached_entry, depth >= iid_min_leaf_distance {
    // We hit the cache. No need to for IID at all, just return the PV move.
    Ok(transposition.Entry(eval:, ..)), _ -> state.return(eval.best_move)
    // We missed the cache and we're far from the leaves. So we should
    // iteratively deepen for the PV move.
    Error(Nil), True -> {
      use eval <- state.do(iteratively_deepen(
        game,
        1,
        alpha,
        beta,
        SearchOpts(max_depth: Some(iid_depth)),
        history,
      ))
      state.return(eval.best_move)
    }
    // Cache miss but we're close to the leaves. Too bad.
    Error(Nil), False -> state.return(None)
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
) -> State(SearchState, #(List(move.Move(move.ValidInContext)), Int)) {
  use best_move <- state.do(get_pv_move(game, depth, alpha, beta, history))

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

  // We use MVV-LVA for sorting capture_promotion moves:
  // We sort most valuable victim, most valuable first, falling back to
  // sorting by least valuable attacker, least valuable first.
  // For promotions, we count it as the promoted piece
  let compare_mvv_lva = order_addons.or(compare_mvv, compare_lva)
  let capture_promotion_moves =
    list.sort(capture_promotion_moves, compare_mvv_lva)

  use compare_quiet_history <- state.map({
    use search_state: SearchState <- state.select
    compare_quiet_history(search_state.history)
  })
  let quiet_moves = list.sort(quiet_moves, compare_quiet_history)

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
