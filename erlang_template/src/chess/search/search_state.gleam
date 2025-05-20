import chess/game
import chess/piece
import chess/search/evaluation.{type Evaluation, Evaluation}
import chess/search/transposition
import chess/square
import gleam/dict
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import util/state.{type State, State}

pub type SearchState {
  SearchState(
    transposition: transposition.Table,
    previous_games: dict.Dict(game.Hash, game.Game),
    history: dict.Dict(#(square.Square, piece.Piece), Int),
    stats: SearchStats,
  )
}

pub fn new(now: timestamp.Timestamp) {
  SearchState(
    transposition: dict.new(),
    history: dict.new(),
    previous_games: dict.new(),
    stats: SearchStats(
      nodes_searched: 0,
      nodes_searched_at_init_time: 0,
      init_time: now,
      times_pruned: 0,
      prune_stats: [],
      cache_hits: 0,
      cache_misses: 0,
    ),
  )
}

pub fn is_previous_game(game: game.Game) -> State(SearchState, Bool) {
  use search_state: SearchState <- state.select()
  search_state.previous_games
  |> dict.get(game.hash(game))
  |> result.map(game.equal(_, game))
  |> result.unwrap(False)
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
) -> State(SearchState, Result(transposition.Entry, Nil)) {
  use search_state: SearchState <- State(run: _)
  let transposition = search_state.transposition
  let stats = search_state.stats
  let entry = dict.get(transposition, hash)
  let #(transposition, stats) = case entry {
    Ok(entry) -> {
      let last_accessed = search_state.stats.nodes_searched
      let entry = transposition.Entry(..entry, last_accessed:)

      let transposition = dict.insert(transposition, hash, entry)
      let stats = SearchStats(..stats, cache_hits: stats.cache_hits + 1)
      #(transposition, stats)
    }
    _ -> #(
      transposition,
      SearchStats(..stats, cache_misses: stats.cache_misses + 1),
    )
  }
  #(entry, SearchState(..search_state, transposition:, stats:))
}

pub fn transposition_insert(
  hash: game.Hash,
  entry: #(evaluation.Depth, Evaluation),
) -> State(SearchState, Nil) {
  let #(depth, eval) = entry
  use search_state: SearchState <- state.modify
  let last_accessed = search_state.stats.nodes_searched
  let entry = transposition.Entry(depth:, eval:, last_accessed:)
  let transposition = dict.insert(search_state.transposition, hash, entry)
  SearchState(..search_state, transposition:)
}

pub fn transposition_prune(
  when policy: TranspositionPolicy,
  do method: TranspositionPruneMethod,
) -> State(SearchState, Nil) {
  use policy_met <- state.do(
    transposition_prune_policy_met(_, policy)
    |> state.select,
  )

  case policy_met {
    True -> {
      use search_state: SearchState <- state.modify
      let size_before = dict.size(search_state.transposition)
      let stats = search_state.stats
      let transposition = case method {
        ByRecency(max_recency:) ->
          search_state.transposition
          |> dict.filter(fn(_, entry) {
            search_state.stats.nodes_searched - entry.last_accessed
            <= max_recency
          })
      }
      let size_after = dict.size(transposition)
      // TODO: Prefer not to do this; it violates purity while everything else
      // is completely pure. It might be useful now to see how much pruning is
      // done in the searcher before it gets killed and the work is lost though
      {
        io.println_error("Pruned.")
        io.println_error("  Size before: " <> int.to_string(size_before))
        io.println_error("  Size after: " <> int.to_string(size_after))
      }
      let stats =
        SearchStats(..stats, times_pruned: stats.times_pruned + 1, prune_stats: [
          PruneStats(size_before, size_after, stats.nodes_searched),
          ..stats.prune_stats
        ])
      SearchState(..search_state, transposition:, stats:)
    }
    False -> state.return(Nil)
  }
}

fn transposition_prune_policy_met(
  search_state: SearchState,
  policy: TranspositionPolicy,
) -> Bool {
  case policy {
    Indiscriminately -> True
    LargerThan(max_size) -> dict.size(search_state.transposition) > max_size
  }
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
    // How many times have we pruned the table?
    times_pruned: Int,
    prune_stats: List(PruneStats),
    // How many times have we hit the cache?
    cache_hits: Int,
    // How many times have we missed the cache?
    cache_misses: Int,
  )
}

pub type PruneStats {
  PruneStats(before: Int, after: Int, when: Int)
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
pub fn stats_rezero(now: timestamp.Timestamp) -> State(SearchState, Nil) {
  use search_state: SearchState <- state.modify
  let nodes_searched_at_init_time = search_state.stats.nodes_searched
  let stats =
    SearchStats(
      ..search_state.stats,
      init_time: now,
      nodes_searched_at_init_time:,
      // prune_stats: [],
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
  <> "  Times Pruned: "
  <> stats.times_pruned |> int.to_string
  <> "\n"
  <> "  Cache hits/Cache misses: "
  <> {
    stats.cache_hits |> int.to_string
    <> "/"
    <> stats.cache_misses |> int.to_string
    <> " ("
    <> {
      {
        int.to_float(stats.cache_hits * 100)
        /. { int.to_float(int.max(stats.cache_hits + stats.cache_misses, 1)) }
      }
      |> float.to_precision(2)
      |> float.to_string
    }
    <> "% hit, "
    <> {
      int.to_float(stats.cache_misses * 100)
      /. { int.to_float(int.max(stats.cache_hits + stats.cache_misses, 1)) }
    }
    |> float.to_precision(2)
    |> float.to_string
    <> "% misses)"
  }
  <> "\n"
  <> "  Prune stats: "
  <> {
    "["
    <> stats.prune_stats
    |> list.map(fn(x) {
      let PruneStats(before, after, when) = x
      "("
      <> int.to_string(before)
      <> " -> "
      <> int.to_string(after)
      <> ")@"
      <> int.to_string(when)
    })
    |> string.join("; ")
    <> "]"
  }
  <> "\n"
}

fn stats_nodes_per_second(
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
