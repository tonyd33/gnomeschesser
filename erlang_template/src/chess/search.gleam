import chess/evaluate
import chess/game
import chess/move
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

pub type SearchMessage {
  SearchUpdate(
    best_evaluation: Evaluation,
    game: game.Game,
    transposition: TranspositionTable,
  )
  SearchDone(
    best_evaluation: Evaluation,
    game: game.Game,
    transposition: TranspositionTable,
  )
}

pub type SearchOpts {
  SearchOpts(max_depth: Option(Int))
}

pub const default_search_opts = SearchOpts(max_depth: None)

type SearchContext =
  TranspositionTable

pub type Depth =
  Int

pub type Evaluation {
  Evaluation(
    score: ExtendedInt,
    node_type: NodeType,
    best_move: Option(move.Move(move.ValidInContext)),
    best_line: List(move.Move(move.ValidInContext)),
  )
}

/// https://www.chessprogramming.org/Node_Types
pub type NodeType {
  // Exact Score
  PV
  // Lower Bound
  Cut
  // Upper Bound
  All
}

fn evaluation_negate(evaluation: Evaluation) -> Evaluation {
  let node_type = case evaluation.node_type {
    Cut -> All
    All -> Cut
    PV -> PV
  }
  Evaluation(..evaluation, score: xint.negate(evaluation.score), node_type:)
}

pub fn new(
  game: game.Game,
  transposition: TranspositionTable,
  search_subject: process.Subject(SearchMessage),
  opts: SearchOpts,
) -> process.Pid {
  process.start(
    fn() {
      {
        let now = timestamp.system_time()
        use _ <- state.do(tt_zero(now))
        search(search_subject, game, 1, opts)
      }
      |> state.go(transposition)
    },
    True,
  )
}

fn search(
  search_subject: process.Subject(SearchMessage),
  game: game.Game,
  current_depth: Depth,
  opts: SearchOpts,
) -> State(SearchContext, Nil) {
  // perform the search at each depth, the negamax function will handle sorting and caching
  use best_evaluation <- state.do(negamax_alphabeta_failsoft(
    game,
    current_depth,
    xint.NegInf,
    xint.PosInf,
  ))
  use _ <- state.do(tt_prune_by(
    when: LargerThan(max_tt_size),
    do: ByRecency(max_tt_recency),
  ))
  let now = timestamp.system_time()
  use info <- state.do(tt_info_s(now))

  use _ <- state.do(tt_zero(now))
  use tt <- state.do(state.get())

  process.send(
    search_subject,
    SearchUpdate(best_evaluation:, game:, transposition: tt),
  )
  // TODO: use a logging library for this
  io.print_error(info)

  case opts.max_depth {
    Some(max_depth) if current_depth >= max_depth -> {
      process.send(
        search_subject,
        SearchDone(best_evaluation:, game:, transposition: tt),
      )
      state.return(Nil)
    }
    _ -> search(search_subject, game, current_depth + 1, opts)
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
  depth: Depth,
  alpha: ExtendedInt,
  beta: ExtendedInt,
) -> State(SearchContext, Evaluation) {
  let game_hash = game.hash(game)

  // TODO: check for cache collision here
  use cached_evaluation <- state.do(
    tt_get_s(game_hash)
    |> state.fmap(
      result.then(_, fn(x) {
        let TranspositionEntry(cached_depth, evaluation, _) = x
        use <- bool.guard(cached_depth < depth, Error(Nil))
        case evaluation {
          Evaluation(_, PV, _, _) -> Ok(evaluation)
          Evaluation(score, Cut, _, _) ->
            case xint.gte(score, beta) {
              True -> Ok(evaluation)
              False -> Error(Nil)
            }
          Evaluation(score, All, _, _) ->
            case xint.lte(score, alpha) {
              True -> Ok(evaluation)
              False -> Error(Nil)
            }
        }
      }),
    ),
  )

  use <- result.lazy_unwrap(result.map(cached_evaluation, state.return))

  use evaluation <- state.do(do_negamax_alphabeta_failsoft(
    game,
    depth,
    alpha,
    beta,
  ))

  use _ <- state.do(tt_insert_s(game_hash, #(depth, evaluation)))
  use _ <- state.do(tt_inc_s())
  use _ <- state.do(tt_prune_by(
    when: LargerThan(max_tt_size),
    do: ByRecency(max_tt_recency),
  ))
  state.return(evaluation)
}

fn do_negamax_alphabeta_failsoft(
  game: game.Game,
  depth: Depth,
  alpha: ExtendedInt,
  beta: ExtendedInt,
) -> State(SearchContext, Evaluation) {
  use <- bool.lazy_guard(depth <= 0, fn() {
    let score = quiesce(game, alpha, beta)
    state.return(
      Evaluation(score:, node_type: PV, best_move: None, best_line: []),
    )
  })

  use move_game_list <- state.do(state.gets(sorted_moves(game, _)))

  use <- bool.lazy_guard(list.is_empty(move_game_list), fn() {
    // if checkmate/stalemate
    let score = case game.is_check(game, game.turn(game)) {
      True -> xint.NegInf
      False -> xint.Finite(0)
    }
    state.return(
      Evaluation(score:, node_type: PV, best_move: None, best_line: []),
    )
  })

  // We iterate through every move and perform minimax to evaluate said move
  // accumulator keeps track of best evaluation while updating the node type
  state.fold_until_s(
    move_game_list,
    #(Evaluation(xint.NegInf, PV, None, []), alpha),
    fn(acc, move_game) {
      {
        let #(best_evaluation, alpha) = acc
        let #(move, game) = move_game
        use evaluation <- state.do(negamax_alphabeta_failsoft(
          game,
          depth - 1,
          xint.negate(beta),
          xint.negate(alpha),
        ))
        let evaluation =
          Evaluation(
            ..evaluation_negate(evaluation),
            best_move: Some(move),
            best_line: [move, ..evaluation.best_line],
          )
        let best_evaluation = case
          xint.lt(best_evaluation.score, evaluation.score)
        {
          True -> evaluation
          False -> best_evaluation
        }
        let alpha = xint.max(alpha, evaluation.score)

        state.return(#(evaluation, best_evaluation, alpha))
      }
      |> state.fmap(fn(x) {
        // beta-cutoff
        let #(evaluation, best_evaluation, alpha) = x
        case xint.gte(evaluation.score, beta) {
          True -> {
            let best_evaluation = Evaluation(..best_evaluation, node_type: Cut)
            list.Stop(#(best_evaluation, alpha))
          }
          False -> list.Continue(#(best_evaluation, alpha))
        }
      })
    },
  )
  |> state.fmap(fn(x) { x.0 })
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
  transposition: TranspositionTable,
) -> List(#(move.Move(move.ValidInContext), game.Game)) {
  // retrieve the cached transposition table data
  game.valid_moves(game)
  |> list.filter_map(fn(move) {
    // TODO: we can probably generate the sorted moves without applying every game
    // Since we only need the current PV
    let new_game = game.apply(game, move)
    // TODO: Make this stateful and update the transposition table
    // - Why does this need to update the transposition table? This part is read-only right?
    let evaluation = case dict.get(transposition.dict, game.hash(new_game)) {
      Ok(TranspositionEntry(_, evaluation, _)) ->
        // negate the evaluation so that it's relative to our current game
        evaluation_negate(evaluation) |> Some
      Error(Nil) -> None
    }
    Ok(#(#(move, new_game), evaluation))
  })
  // "smallest" elements get sorted first
  |> list.sort(fn(a, b) {
    let #(_a_move, a) = a
    let #(_b_move, b) = b
    case a, b {
      None, None -> order.Eq
      _, None -> order.Lt
      None, _ -> order.Gt
      Some(a), Some(b) -> {
        case a, b {
          Evaluation(_, Cut, _, _), _ -> order.Gt
          _, Evaluation(_, Cut, _, _) -> order.Lt
          Evaluation(a_score, _, _, _), Evaluation(b_score, _, _, _) ->
            xint.compare(b_score, a_score)
        }
      }
    }
  })
  |> list.map(pair.first)
}

/// A table to cache calculation results.
/// Additionally, we store extra metadata to allow us to prune the table if it
/// gets too large.
///
pub type TranspositionTable {
  TranspositionTable(
    dict: dict.Dict(game.Hash, TranspositionEntry),
    // Honestly, this attribute doesn't really belong in here. it belongs more
    // in `SearchContext`, but... whatever.
    nodes_searched: Int,
    // TODO: Docs
    checkpoint: Int,
    // Same with this. The only reason we store this is so calculate the
    // number of nodes searched per second (nps).
    init_time: timestamp.Timestamp,
  )
}

/// We don't let the transposition table get bigger than this
///
const max_tt_size = 100_000

/// When pruning the transposition table, how recent of entries do we decide to
/// keep?
///
const max_tt_recency = 50_000

/// We also store "when" an entry was last accessed so we can prune it if need be.
/// "when" should be any monotonic non-decreasing measure; time is an obvious
/// choice, but the number of nodes searched serves us just as well.
///
pub type TranspositionEntry {
  TranspositionEntry(depth: Depth, eval: Evaluation, last_accessed: Int)
}

/// When should we prune the transposition table?
///
pub type TranspositionPolicy {
  Indiscriminately
  LargerThan(max_size: Int)
}

/// How should we prune the transposition table?
///
pub type TranspositionRemediation {
  ByRecency(max_recency: Int)
}

pub fn tt_new(now: timestamp.Timestamp) {
  TranspositionTable(dict.new(), 0, 0, now)
}

fn tt_nps(tt: TranspositionTable, now: timestamp.Timestamp) -> Float {
  let dt = timestamp.difference(tt.init_time, now) |> duration.to_seconds
  case dt {
    0.0 -> 0.0
    _ -> {
      let assert Ok(nps) =
        { tt.nodes_searched - tt.checkpoint }
        |> int.to_float
        |> float.divide(dt)
      nps
    }
  }
}

fn tt_info(tt: TranspositionTable, now: timestamp.Timestamp) -> String {
  let nps = tt_nps(tt, now)
  ""
  <> "Transposition Table Stats:\n"
  <> "  NPS: "
  <> { nps |> float.to_precision(2) |> float.to_string }
  <> "\n"
  <> "  Nodes: "
  <> { tt.nodes_searched |> int.to_string }
  <> "\n"
  <> "  Checkpoint: "
  <> { tt.checkpoint |> int.to_string }
  <> "\n"
  <> "  DN: "
  <> { { tt.nodes_searched - tt.checkpoint } |> int.to_string }
  <> "\n"
  <> "  Size: "
  <> { dict.size(tt.dict) |> int.to_string }
  <> "\n"
}

pub fn tt_info_s(now: timestamp.Timestamp) {
  state.gets(tt_info(_, now))
}

pub fn tt_get_s(
  hash: game.Hash,
) -> State(TranspositionTable, Result(TranspositionEntry, Nil)) {
  State(run: fn(tt: TranspositionTable) {
    let rv = dict.get(tt.dict, hash)
    let dict_ = case rv {
      Ok(v) ->
        dict.insert(
          tt.dict,
          hash,
          TranspositionEntry(..v, last_accessed: tt.nodes_searched),
        )
      _ -> tt.dict
    }
    let tt_ = TranspositionTable(..tt, dict: dict_)

    #(rv, tt_)
  })
}

pub fn tt_inc_s() -> State(TranspositionTable, Nil) {
  use tt <- state.modify
  TranspositionTable(..tt, nodes_searched: tt.nodes_searched + 1)
}

pub fn tt_insert_s(
  hash: game.Hash,
  e: #(Depth, Evaluation),
) -> State(TranspositionTable, Nil) {
  let #(depth, eval) = e
  use tt <- state.modify
  TranspositionTable(
    ..tt,
    dict: dict.insert(
      tt.dict,
      hash,
      TranspositionEntry(depth, eval, tt.nodes_searched),
    ),
  )
}

fn tt_policy_met(tt: TranspositionTable, policy: TranspositionPolicy) -> Bool {
  case policy {
    Indiscriminately -> True
    LargerThan(ms) -> dict.size(tt.dict) > ms
  }
}

fn tt_remediate(tt: TranspositionTable, remedy: TranspositionRemediation) {
  case remedy {
    ByRecency(mr) ->
      TranspositionTable(
        ..tt,
        dict: dict.filter(tt.dict, fn(_, v) {
          tt.nodes_searched - v.last_accessed <= mr
        }),
      )
  }
}

fn tt_remediate_s(
  remedy: TranspositionRemediation,
) -> State(TranspositionTable, Nil) {
  use tt <- state.modify
  tt_remediate(tt, remedy)
}

pub fn tt_prune_by(
  when policy: TranspositionPolicy,
  do remedy: TranspositionRemediation,
) -> State(TranspositionTable, Nil) {
  use met <- state.do(state.gets(tt_policy_met(_, policy)))

  case met {
    True -> tt_remediate_s(remedy)
    False -> state.return(Nil)
  }
}

/// "Zero" out the transposition table's log so that the next time we try
/// to get its stats, they're calculated with respect to the current state.
/// In particular, this is used when we want to reset the initial time for
/// the NPS measure.
///
pub fn tt_zero(now: timestamp.Timestamp) {
  use tt <- state.modify
  TranspositionTable(..tt, init_time: now, checkpoint: tt.nodes_searched)
}
