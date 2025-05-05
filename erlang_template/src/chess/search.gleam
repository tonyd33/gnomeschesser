import chess/evaluate
import chess/game
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

pub type SearchMessage {
  SearchUpdate(
    best_move: game.Move,
    game: game.GameHash,
    transposition: TranspositionTable,
  )
}

type SearchContext =
  TranspositionTable

pub type Depth =
  Int

pub type Evaluation {
  Evaluation(score: Float, node_type: NodeType, best_move: Option(game.Move))
}

// https://www.chessprogramming.org/Node_Types
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
  Evaluation(..evaluation, score: float.negate(evaluation.score), node_type:)
}

pub const new = new_state

pub fn new_state(
  game: game.Game,
  transposition: TranspositionTable,
  search_subject: process.Subject(SearchMessage),
) -> process.Pid {
  // Spawns a searcher thread, NOT linked so we can kill it whenever
  process.start(
    fn() { state.go(search_state(search_subject, game, 1), transposition) },
    False,
  )
}

fn search_state(
  search_subject: process.Subject(SearchMessage),
  game: game.Game,
  current_depth: Depth,
) -> State(SearchContext, Nil) {
  let now = timestamp.system_time()
  // perform the search at each depth, the negamax function will handle sorting and caching
  use best_evaluation <- state.do(negamax_alphabeta_failsoft(
    game,
    current_depth,
    -1.0,
    1.0,
  ))
  use _ <- state.do(tt_prune_by(
    when: LargerThan(max_tt_size),
    do: ByRecency(max_tt_recency),
  ))
  use info <- state.do(tt_info_s(now))
  use tt <- state.do(state.get())
  let Evaluation(_score, _node_type, best_move) = best_evaluation

  // IO actions
  {
    case best_move {
      Some(best_move) ->
        process.send(
          search_subject,
          SearchUpdate(best_move, game.to_hash(game), tt),
        )
      None -> Nil
    }
    io.print(info)
  }

  search_state(search_subject, game, current_depth + 1)
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
  alpha: Float,
  beta: Float,
) -> State(SearchContext, Evaluation) {
  let game_hash = game.to_hash(game)

  // TODO: check for cache collision here
  use cached_evaluation <- state.do(
    tt_get_s(game_hash)
    |> state.fmap(
      result.then(_, fn(x) {
        let TranspositionEntry(cached_depth, evaluation, _) = x
        use <- bool.guard(cached_depth < depth, Error(Nil))
        case evaluation {
          Evaluation(_, PV, _) -> Ok(evaluation)
          Evaluation(score, Cut, _) if score >=. beta -> Ok(evaluation)
          Evaluation(score, All, _) if score <=. alpha -> Ok(evaluation)
          _ -> Error(Nil)
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
  alpha: Float,
  beta: Float,
) -> State(SearchContext, Evaluation) {
  use <- bool.lazy_guard(depth <= 0, fn() {
    let score = quiesce(game, alpha, beta)
    state.return(Evaluation(score:, node_type: PV, best_move: None))
  })

  use move_game_list <- state.do(state.gets(sorted_moves(game, _)))

  use <- bool.lazy_guard(list.is_empty(move_game_list), fn() {
    // if checkmate/stalemate
    let score = case game.is_check(game) {
      True -> -1.0
      False -> 0.0
    }
    state.return(Evaluation(score:, node_type: PV, best_move: None))
  })

  // We iterate through every move and perform minimax to evaluate said move
  // accumulator keeps track of best evaluation while updating the node type
  use #(best_evaluation, _alpha) <- state.do(
    state.fold_until_s(
      move_game_list,
      #(Evaluation(-1.0, PV, None), alpha),
      fn(acc, move_game) {
        {
          let #(best_evaluation, alpha) = acc
          let #(move, game) = move_game
          use evaluation <- state.do(negamax_alphabeta_failsoft(
            game,
            depth - 1,
            float.negate(beta),
            float.negate(alpha),
          ))
          let evaluation =
            Evaluation(..evaluation_negate(evaluation), best_move: Some(move))
          let best_evaluation = case best_evaluation.score <. evaluation.score {
            True -> evaluation
            False -> best_evaluation
          }
          let alpha = float.max(alpha, evaluation.score)

          state.return(#(evaluation, best_evaluation, alpha))
        }
        |> state.fmap(fn(x) {
          // beta-cutoff
          let #(evaluation, best_evaluation, alpha) = x
          case evaluation.score >=. beta {
            True -> {
              let best_evaluation =
                Evaluation(..best_evaluation, node_type: Cut)
              list.Stop(#(best_evaluation, alpha))
            }
            False -> list.Continue(#(best_evaluation, alpha))
          }
        })
      },
    ),
  )

  state.return(best_evaluation)
}

// returns the score of the current game while checking
// every capture and check
// scores are from the perspective of the active player
// If white's turn, +1 is white's advantage
// If black's turn, +1 is black's advantage
// alpha is the "best" score for active player
// beta is the "best" score for non-active player
fn quiesce(game: game.Game, alpha: Float, beta: Float) -> Float {
  let score = evaluate.game(game) *. evaluate.player(game.turn(game))
  use <- bool.guard(score >=. beta, score)
  let alpha = float.max(alpha, score)

  let move_game_list =
    game.moves(game)
    |> list.map(fn(move) {
      let assert Ok(new_game) = game.apply(game, move)
      #(move, new_game)
    })
  let #(best_score, _) =
    move_game_list
    |> list.filter(fn(move_game) {
      let #(move, _new_game) = move_game
      game.move_is_capture(move)
    })
    |> list.fold_until(#(score, alpha), fn(acc, move_game) {
      let #(_move, new_game) = move_game
      let #(best_score, alpha) = acc
      let score =
        float.negate(quiesce(new_game, float.negate(beta), float.negate(alpha)))

      use <- bool.guard(score >=. beta, list.Stop(#(score, alpha)))
      list.Continue(#(float.max(best_score, score), float.max(alpha, score)))
    })
  best_score
}

// sort moves from best to worse, which improves alphabeta pruning
fn sorted_moves(
  game: game.Game,
  transposition: TranspositionTable,
) -> List(#(game.Move, game.Game)) {
  game.moves(game)
  |> list.map(fn(move) {
    // retrieve the cached transposition table data
    // negate the evaluation so that it's relative to our current game
    let assert Ok(new_game) = game.apply(game, move)
    let evaluation = case dict.get(transposition.dict, game.to_hash(new_game)) {
      Ok(TranspositionEntry(_, evaluation, _)) ->
        Some(evaluation_negate(evaluation))
      Error(Nil) -> None
    }
    #(#(move, new_game), evaluation)
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
          Evaluation(_, Cut, _), _ -> order.Gt
          _, Evaluation(_, Cut, _) -> order.Lt
          Evaluation(a_score, _, _), Evaluation(b_score, _, _) ->
            float.compare(b_score, a_score)
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
    dict: dict.Dict(game.GameHash, TranspositionEntry),
    // Honestly, this attribute doesn't really belong in here. it belongs more
    // in `SearchContext`, but... whatever.
    nodes_searched: Int,
    // Same with this. The only reason we store this is so calculate the
    // number of nodes searched per second (nps).
    init_time: timestamp.Timestamp,
  )
}

/// We don't let the transposition table get bigger than this
///
const max_tt_size = 20_000

/// When pruning the transposition table, how recent of entries do we decide to
/// keep?
///
const max_tt_recency = 5000

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
  TranspositionTable(dict.new(), 0, now)
}

fn tt_nps(tt: TranspositionTable, now: timestamp.Timestamp) -> Float {
  let dt = timestamp.difference(tt.init_time, now)
  let assert Ok(nps) =
    tt.nodes_searched
    |> int.to_float
    |> float.divide(duration.to_seconds(dt))

  nps
}

fn tt_info(tt: TranspositionTable, now: timestamp.Timestamp) -> String {
  let nps = tt_nps(tt, now)
  ""
  <> "Stats:\n"
  <> "  NPS: "
  <> { nps |> float.to_precision(2) |> float.to_string }
  <> "\n"
  <> "  Nodes: "
  <> { tt.nodes_searched |> int.to_string }
  <> "\n"
  <> "  Size: "
  <> { dict.size(tt.dict) |> int.to_string }
  <> "\n"
}

pub fn tt_info_s(now: timestamp.Timestamp) {
  state.gets(tt_info(_, now))
}

pub fn tt_get_s(
  hash: game.GameHash,
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
  hash: game.GameHash,
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
