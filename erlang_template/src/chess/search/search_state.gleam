import chess/evaluate
import chess/game
import chess/move
import chess/piece
import chess/search/evaluation.{type Evaluation, Evaluation}
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

pub type SearchState {
  SearchState(transposition: transposition.Table, stats: SearchStats)
}

pub type SearchStats {
  /// We store extra metadata to allow us to prune the table if it
  /// gets too large.
  SearchStats(
    nodes_searched: Int,
    // The node searched the last time we cleared the data
    nodes_searched_last_depth: Int,
    // Same with this. The only reason we store this is so calculate the
    // number of nodes searched per second (nps).
    init_time: timestamp.Timestamp,
  )
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

pub fn new(now: timestamp.Timestamp) {
  SearchState(
    transposition: dict.new(),
    stats: SearchStats(
      nodes_searched: 0,
      nodes_searched_last_depth: 0,
      init_time: now,
    ),
  )
}

pub fn get_transposition_entry(
  hash: game.Hash,
) -> State(SearchState, Result(transposition.Entry, Nil)) {
  use SearchState(stats:, transposition:): SearchState <- State(run: _)
  let entry = dict.get(transposition, hash)
  let transposition = case entry {
    Ok(entry) ->
      dict.insert(
        transposition,
        hash,
        transposition.Entry(..entry, last_accessed: stats.nodes_searched),
      )
    _ -> transposition
  }
  #(entry, SearchState(stats:, transposition:))
}

pub fn increment_nodes_searched() -> State(SearchState, Nil) {
  use search_state: SearchState <- state.modify
  let stats = search_state.stats
  SearchState(
    ..search_state,
    stats: SearchStats(..stats, nodes_searched: stats.nodes_searched + 1),
  )
}

pub fn insert_transposition_entry(
  hash: game.Hash,
  entry: #(evaluation.Depth, Evaluation),
) -> State(SearchState, Nil) {
  let #(depth, eval) = entry
  use SearchState(stats:, transposition:) <- state.modify
  let transposition =
    dict.insert(
      transposition,
      hash,
      transposition.Entry(depth, eval, stats.nodes_searched),
    )
  SearchState(stats:, transposition:)
}

pub fn prune_transposition_table(
  when policy: TranspositionPolicy,
  do method: TranspositionPruneMethod,
) -> State(SearchState, Nil) {
  use policy_met <- state.do(
    state_prune_policy_met(_, policy)
    |> state.select,
  )

  case policy_met {
    True -> {
      use SearchState(transposition:, stats:) <- state.modify
      let transposition = case method {
        ByRecency(max_recency:) ->
          dict.filter(transposition, fn(_, v) {
            stats.nodes_searched - v.last_accessed <= max_recency
          })
      }
      SearchState(transposition:, stats:)
    }
    False -> state.return(Nil)
  }
}

fn state_prune_policy_met(
  search_state: SearchState,
  policy: TranspositionPolicy,
) -> Bool {
  case policy {
    Indiscriminately -> True
    LargerThan(max_size) -> dict.size(search_state.transposition) > max_size
  }
}

/// "Zero" out the transposition table's log so that the next time we try
/// to get its stats, they're calculated with respect to the current state.
/// In particular, this is used when we want to reset the initial time for
/// the NPS measure.
///
pub fn set_stats_zero(now: timestamp.Timestamp) -> State(SearchState, Nil) {
  use SearchState(transposition:, stats:) <- state.modify
  SearchState(
    transposition:,
    stats: SearchStats(
      ..stats,
      init_time: now,
      nodes_searched_last_depth: stats.nodes_searched,
    ),
  )
}

pub fn get_stat_string(
  search_state: SearchState,
  now: timestamp.Timestamp,
) -> String {
  let SearchState(transposition:, stats:) = search_state
  let nps = state_get_nodes_per_second(search_state, now)
  ""
  <> "Transposition Table Stats:\n"
  <> "  NPS: "
  <> nps |> float.to_precision(2) |> float.to_string
  <> "\n"
  <> "  Nodes: "
  <> stats.nodes_searched |> int.to_string
  <> "\n"
  <> "  Checkpoint: "
  <> stats.nodes_searched_last_depth |> int.to_string
  <> "\n"
  <> "  Nodes in Depth: "
  <> { stats.nodes_searched - stats.nodes_searched_last_depth }
  |> int.to_string
  <> "\n"
  <> "  Size: "
  <> dict.size(transposition) |> int.to_string
  <> "\n"
}

fn state_get_nodes_per_second(
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
        { stats.nodes_searched - stats.nodes_searched_last_depth }
        |> int.to_float
        |> float.divide(dt)
      nps
    }
  }
}
