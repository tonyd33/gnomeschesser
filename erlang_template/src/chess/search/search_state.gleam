import chess/piece
import chess/search/evaluation.{type Evaluation, Evaluation}
import chess/search/transposition
import chess/square
import gleam/dict
import gleam/float
import gleam/int
import gleam/result
import gleam/time/duration
import gleam/time/timestamp
import util/state.{type State, State}

pub type SearchState {
  SearchState(
    transposition: transposition.Table,
    history: dict.Dict(#(square.Square, piece.Piece), Int),
    stats: SearchStats,
  )
}

pub fn new(now: timestamp.Timestamp) {
  SearchState(
    transposition: dict.new(),
    history: dict.new(),
    stats: SearchStats(
      nodes_searched: 0,
      nodes_searched_at_init_time: 0,
      init_time: now,
      hits: 0,
      misses: 0,
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

/// To reduce the need of manual trimming when the transposition table gets too
/// large, we reduce the key space by taking only a certain amount of lower
/// bits. This current mask gives us a max size of 2^17, or 131072 entries.
const key_mask = 0x3FFFF

fn transposition_key_reduce(key: Int) {
  int.bitwise_and(key, key_mask)
}

pub fn transposition_get(
  hash: Int,
) -> State(SearchState, Result(transposition.Entry, Nil)) {
  use search_state: SearchState <- State(run: _)
  let transposition = search_state.transposition
  let key = transposition_key_reduce(hash)
  let entry = dict.get(transposition, key)
  case entry {
    Ok(entry) if entry.hash == hash -> {
      #(
        Ok(entry),
        SearchState(
          ..search_state,
          transposition:,
          stats: SearchStats(
            ..search_state.stats,
            hits: search_state.stats.hits + 1,
          ),
        ),
      )
    }
    _ -> #(
      Error(Nil),
      SearchState(
        ..search_state,
        stats: SearchStats(
          ..search_state.stats,
          misses: search_state.stats.misses + 1,
        ),
      ),
    )
  }
}

pub fn transposition_insert(
  hash: Int,
  entry: #(evaluation.Depth, Evaluation),
) -> State(SearchState, Nil) {
  let #(depth, eval) = entry
  use search_state: SearchState <- state.modify
  let entry = transposition.Entry(hash:, depth:, eval:)
  let key = transposition_key_reduce(hash)
  let transposition = dict.insert(search_state.transposition, key, entry)
  // let transposition = {
  //   use maybe_entry <- dict.upsert(search_state.transposition, key)
  //   case maybe_entry {
  //     Some(existing_entry) if existing_entry.depth > depth -> existing_entry
  //     _ -> entry
  //   }
  // }
  SearchState(..search_state, transposition:)
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
    hits: Int,
    misses: Int,
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
  let transposition = search_state.transposition
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
  <> dict.size(transposition) |> int.to_string
  <> "\n"
  <> {
    "  Cache hits, misses, %: "
    <> int.to_string(stats.hits)
    <> ", "
    <> int.to_string(stats.misses)
    <> ", "
    <> float.to_string(float.to_precision(
      int.to_float(stats.hits)
        *. 100.0
        /. int.to_float(stats.hits + stats.misses),
      2,
    ))
    <> "%"
    <> "\n"
  }
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
