import chess/actors/auditor
import chess/game
import chess/piece
import chess/search/evaluation.{type Depth, type Evaluation, Evaluation}
import chess/search/transposition
import chess/square
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set
import gleam/time/duration
import gleam/time/timestamp
import util/state.{type State, State}
import util/xint.{type ExtendedInt}

pub type SearchState {
  SearchState(
    auditor_channel: Subject(auditor.Message(Int, #(Depth, Evaluation))),
    history: dict.Dict(#(square.Square, piece.Piece), Int),
    stats: SearchStats,
  )
}

pub fn new(
  now: timestamp.Timestamp,
  auditor_channel: Subject(auditor.Message(Int, #(Depth, Evaluation))),
) {
  SearchState(
    auditor_channel:,
    history: dict.new(),
    stats: SearchStats(
      nodes_searched: 0,
      nodes_searched_at_init_time: 0,
      init_time: now,
      failed: 0,
    ),
  )
}

const max_history: Int = 50

/// https://www.chessprogramming.org/History_Heuristic
pub fn history_get(
  key: #(square.Square, piece.Piece),
) -> State(SearchState, Int) {
  use search_state: SearchState <- state.select()
  dict.get(search_state.history, key) |> result.unwrap(0)
}

/// https://www.chessprogramming.org/History_Heuristic
pub fn history_update(
  key: #(square.Square, piece.Piece),
  bonus: Int,
) -> State(SearchState, Nil) {
  let clamped_bonus = int.clamp(bonus, -max_history, max_history)
  use search_state: SearchState <- state.modify
  let history_score = search_state.history |> dict.get(key) |> result.unwrap(0)
  let history_score =
    history_score
    + clamped_bonus
    - { history_score * int.absolute_value(clamped_bonus) / max_history }
  let history = search_state.history |> dict.insert(key, history_score)
  SearchState(..search_state, history:)
}

/// When should we prune the transposition table?
///
pub type TranspositionPolicy {
  Indiscriminately
  LargerThan(max_size: Int)
}

/// How should we prune the transposition table?
///
pub type TranspositionPruneMethod {
  ByRecency(max_recency: Int)
}

pub fn transposition_get(
  hash: game.Hash,
) -> State(SearchState, Result(#(Depth, Evaluation), Nil)) {
  use state: SearchState <- state.select
  case process.try_call(state.auditor_channel, auditor.Get(hash, _), 10) {
    Ok(Ok(x)) -> Ok(x.value)
    Ok(Error(_)) -> Error(Nil)
    Error(_) -> {
      // echo "failing"
      Error(Nil)
    }
  }
}

pub fn transposition_insert(
  hash: game.Hash,
  entry: #(evaluation.Depth, Evaluation),
) -> State(SearchState, Nil) {
  use search_state: SearchState <- state.modify
  process.send(search_state.auditor_channel, auditor.Insert(hash, entry))
  search_state
}

pub fn transposition_prune(
  when policy: TranspositionPolicy,
  do method: TranspositionPruneMethod,
) -> State(SearchState, Nil) {
  state.return(Nil)
}

fn transposition_prune_policy_met(
  search_state: SearchState,
  policy: TranspositionPolicy,
) -> Bool {
  False
}

pub type SearchStats {
  /// We store extra metadata to allow us to prune the table if it
  /// gets too large.
  SearchStats(
    nodes_searched: Int,
    // The node searched the last time we cleared the data
    nodes_searched_at_init_time: Int,
    // Same with this. The only reason we store this is so calculate the
    // number of nodes searched per second (nps).
    init_time: timestamp.Timestamp,
    failed: Int,
  )
}

pub fn stats_increment_nodes_searched() -> State(SearchState, Nil) {
  use search_state: SearchState <- state.modify
  let stats = search_state.stats
  SearchState(
    ..search_state,
    stats: SearchStats(..stats, nodes_searched: stats.nodes_searched + 1),
  )
}

/// "Zero" out the transposition table's log so that the next time we try
/// to get its stats, they're calculated with respect to the current state.
/// In particular, this is used when we want to reset the initial time for
/// the NPS measure.
///
pub fn stats_checkpoint_time(
  now: timestamp.Timestamp,
) -> State(SearchState, Nil) {
  use search_state: SearchState <- state.modify
  let nodes_searched_at_init_time = search_state.stats.nodes_searched
  let stats =
    SearchStats(
      ..search_state.stats,
      init_time: now,
      nodes_searched_at_init_time:,
    )
  SearchState(..search_state, stats:)
}

pub fn stats_to_string(
  search_state: SearchState,
  now: timestamp.Timestamp,
) -> String {
  let size =
    process.try_call(search_state.auditor_channel, auditor.Size, 1000)
    |> result.unwrap(#(-1, -1, -1))
  let stats = search_state.stats
  let nps = stats_nodes_per_second(search_state, now)
  ""
  <> "Transposition Table Stats:\n"
  <> "  NPS: "
  <> nps |> float.to_precision(2) |> float.to_string
  <> "\n"
  <> "  Nodes: "
  <> stats.nodes_searched |> int.to_string
  <> "\n"
  <> "  Checkpoint: "
  <> stats.nodes_searched_at_init_time |> int.to_string
  <> "\n"
  <> "  Nodes in Depth: "
  <> { stats.nodes_searched - stats.nodes_searched_at_init_time }
  |> int.to_string
  <> "\n"
  <> "  Size: "
  <> size.0 |> int.to_string
  <> "\n"
  <> "  Hits: "
  <> size.1 |> int.to_string
  <> "\n"
  <> "  Misses: "
  <> size.2 |> int.to_string
  <> "\n"
}

pub fn stats_nodes_per_second(
  search_state: SearchState,
  now: timestamp.Timestamp,
) -> Float {
  let stats = search_state.stats
  let dt =
    timestamp.difference(stats.init_time, now)
    |> duration.to_seconds
  case dt {
    0.0 -> 0.0
    _ -> {
      let assert Ok(nps) =
        { stats.nodes_searched - stats.nodes_searched_at_init_time }
        |> int.to_float
        |> float.divide(dt)
      nps
    }
  }
}
