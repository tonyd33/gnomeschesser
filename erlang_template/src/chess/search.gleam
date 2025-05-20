import chess/evaluate
import chess/game
import chess/move
import chess/piece
import chess/search/evaluation.{type Evaluation, Evaluation}
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
import gleam/pair
import gleam/result
import gleam/time/duration
import gleam/time/timestamp
import util/state.{type State, State}
import util/xint.{type ExtendedInt}

/// We don't let the transposition table get bigger than this
const max_tt_size = 100_000

/// When pruning the transposition table, how recent of entries do we decide to
/// keep? In ms
const max_tt_recency = 50_000

pub type SearchMessage {
  SearchStateUpdate(search_state: SearchState)
  SearchUpdate(best_evaluation: Evaluation, game: game.Game)
  SearchDone(best_evaluation: Evaluation, game: game.Game)
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
) -> process.Pid {
  process.start(
    fn() {
      {
        let now = timestamp.system_time()
        use _ <- state.do(search_state.stats_checkpoint_time(now))
        search(search_subject, game, 1, opts)
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
      )
    }
    Error(Nil) ->
      search_with_widening_windows(
        game,
        current_depth,
        xint.NegInf,
        xint.PosInf,
        0,
      )
  })

  use _ <- state.do(search_state.transposition_prune(
    when: search_state.LargerThan(max_tt_size),
    do: search_state.ByRecency(max_tt_recency),
  ))

  let now = timestamp.system_time()
  // TODO: use a logging library for this?
  // use info <- state.do(
  //   search_state.stats_to_string(_, now)
  //   |> state.select,
  // )
  // io.print_error(info)

  use _ <- state.do(search_state.stats_checkpoint_time(now))

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

  use search_state <- state.do(state.get_state())
  process.send(search_subject, SearchStateUpdate(search_state:))
  process.send(search_subject, SearchUpdate(best_evaluation:, game:))

  case opts.max_depth {
    Some(max_depth) if current_depth >= max_depth -> {
      process.send(search_subject, SearchDone(best_evaluation:, game:))
      state.return(Nil)
    }
    _ ->
      case best_evaluation.score {
        // terminate the search if we detect we're in mate
        xint.PosInf | xint.NegInf -> state.return(Nil)
        _ -> search(search_subject, game, current_depth + 1, opts)
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
) -> State(SearchState, Evaluation) {
  use best_evaluation <- state.do(negamax_alphabeta_failsoft(
    game,
    depth,
    alpha,
    beta,
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
      )
    }
    score, evaluation.Cut -> {
      search_with_widening_windows(
        game,
        depth,
        alpha,
        score |> xint.add(10 + attempts * 100 |> xint.from_int),
        attempts + 1,
      )
    }
  }
}

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
) -> State(SearchState, Evaluation) {
  let game_hash = game.hash(game)
  // TODO: check for cache collision here
  // return early if we find an entry in the transposition table
  use cached_evaluation <- state.do(
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
    }),
  )

  use <- result.lazy_unwrap(result.map(cached_evaluation, state.return))

  use evaluation <- state.do(do_negamax_alphabeta_failsoft(
    game,
    depth,
    alpha,
    beta,
  ))

  use _ <- state.do(
    search_state.transposition_insert(game_hash, #(depth, evaluation)),
  )
  use _ <- state.do(search_state.stats_increment_nodes_searched())
  use _ <- state.do(search_state.transposition_prune(
    when: search_state.LargerThan(max_tt_size),
    do: search_state.ByRecency(max_tt_recency),
  ))

  state.return(evaluation)
}

fn do_negamax_alphabeta_failsoft(
  game: game.Game,
  depth: evaluation.Depth,
  alpha: ExtendedInt,
  beta: ExtendedInt,
) -> State(SearchState, Evaluation) {
  use <- bool.lazy_guard(depth <= 0, fn() {
    let score = quiesce(game, alpha, beta)
    Evaluation(score:, node_type: evaluation.PV, best_move: None, best_line: [])
    |> state.return
  })

  use moves <- state.do(sorted_moves(game))

  use <- bool.lazy_guard(list.is_empty(moves), fn() {
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
    use #(best_evaluation, alpha), move <- state.list_fold_until_s(moves, #(
      Evaluation(xint.NegInf, evaluation.PV, None, []),
      alpha,
    ))
    use #(best_evaluation, alpha): #(Evaluation, ExtendedInt) <- state.map({
      let game = game.apply(game, move)

      use evaluation <- state.map({
        use is_previous_game <- state.do(search_state.is_previous_game(game))
        // 3 fold repetition
        // If we've encountered this position before, we can assume we're in a 3 fold loop
        // and that this position will resolve to a 0
        use <- bool.guard(is_previous_game, {
          Evaluation(
            score: 0 |> xint.from_int,
            node_type: evaluation.PV,
            best_move: None,
            best_line: [],
          )
          |> state.return
        })

        use evaluation <- state.map(negamax_alphabeta_failsoft(
          game,
          depth - 1,
          xint.negate(beta),
          xint.negate(alpha),
        ))
        evaluation.negate(evaluation)
      })

      let evaluation =
        Evaluation(..evaluation, best_move: Some(move), best_line: [
          move,
          ..evaluation.best_line
        ])

      let best_evaluation = case
        xint.gt(evaluation.score, best_evaluation.score)
      {
        True -> evaluation
        False -> best_evaluation
      }
      let alpha = xint.max(alpha, evaluation.score)
      #(best_evaluation, alpha)
    })
    // beta-cutoff
    case xint.gte(best_evaluation.score, beta) {
      True -> {
        let best_evaluation =
          Evaluation(..best_evaluation, node_type: evaluation.Cut)
        #(best_evaluation, alpha) |> list.Stop
      }
      False -> #(best_evaluation, alpha) |> list.Continue
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

/// sort moves from best to worse, which improves alphabeta pruning
fn sorted_moves(
  game: game.Game,
) -> State(SearchState, List(move.Move(move.ValidInContext))) {
  use entry <- state.map(search_state.transposition_get(game.hash(game)))
  // the cached PV move
  let best_move = case entry {
    Ok(transposition.Entry(_, evaluation, _)) -> evaluation.best_move
    Error(Nil) -> None
  }

  // retrieve the cached transposition table data
  let valid_moves = game.valid_moves(game)

  let #(best_move, capture_promotion_moves, quiet_moves) =
    list.fold(valid_moves, #(None, [], []), fn(acc, move) {
      // TODO: also count checking moves?
      let #(best, capture_promotions, quiet) = acc

      // If this is the best move, just return
      use <- bool.guard(
        option.map(best_move, move.equal(_, move)) |> option.unwrap(False),
        #(Some(move), capture_promotions, quiet),
      )

      // non-quiet moves (captures and promotions get sorted next)
      let move_context = move.get_context(move)
      let is_quiet =
        option.is_none(move_context.capture)
        && option.is_none(move.get_promotion(move))
      case is_quiet {
        True -> #(best, capture_promotions, [move, ..quiet])
        False -> #(best, [move, ..capture_promotions], quiet)
      }
    })

  // We use MVV-LVA for sorting capture_promotion moves
  let capture_promotion_moves =
    capture_promotion_moves
    // first we sort least valuable attacker, least valuable first
    // for promotions, we count it as the promoted piece
    |> list.sort(fn(move1, move2) {
      let piece1 = move.get_context(move1).piece.symbol
      let piece1 =
        move.get_promotion(move1)
        |> option.unwrap(piece1)
      let piece2 = move.get_context(move2).piece.symbol
      let piece2 =
        move.get_promotion(move2)
        |> option.unwrap(piece2)
      int.compare(evaluate.piece_symbol(piece1), evaluate.piece_symbol(piece2))
    })
    // then we sort most valuable victim, most valuable first
    |> list.sort(fn(move1, move2) {
      case move.get_context(move1).capture, move.get_context(move2).capture {
        Some(#(_, piece.Piece(_, a))), Some(#(_, piece.Piece(_, b))) ->
          int.compare(evaluate.piece_symbol(b), evaluate.piece_symbol(a))
        Some(_), _ -> order.Lt
        _, Some(_) -> order.Gt
        _, _ -> order.Eq
      }
    })

  let non_best_move = list.append(capture_promotion_moves, quiet_moves)
  option.map(best_move, fn(best_move) { [best_move, ..non_best_move] })
  |> option.unwrap(non_best_move)
}
