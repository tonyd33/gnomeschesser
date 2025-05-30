import chess/piece
import chess/search/evaluation.{type Evaluation, Evaluation}
import chess/search/transposition
import chess/square
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
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
      total_nodes_searched: 0,
      nodes_searched: 0,
      init_time: now,
      tt_hits: 0,
      tt_misses: 0,
      tt_prunes: 0,
      beta_cutoffs: dict.new(),
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
  hash: Int,
) -> State(SearchState, Result(transposition.Entry, Nil)) {
  use search_state: SearchState <- State(run: _)
  let transposition = search_state.transposition
  let entry = dict.get(transposition, hash)
  case entry {
    Ok(entry) -> {
      let last_accessed = search_state.stats.nodes_searched
      let entry = transposition.Entry(..entry, last_accessed:)

      #(
        Ok(entry),
        SearchState(
          ..search_state,
          transposition: dict.insert(transposition, hash, entry),
          stats: SearchStats(
            ..search_state.stats,
            tt_hits: search_state.stats.tt_hits + 1,
          ),
        ),
      )
    }
    _ -> #(
      entry,
      SearchState(
        ..search_state,
        stats: SearchStats(
          ..search_state.stats,
          tt_misses: search_state.stats.tt_misses + 1,
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
  let last_accessed = search_state.stats.total_nodes_searched
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
      let transposition = case method {
        ByRecency(max_recency:) ->
          search_state.transposition
          |> dict.filter(fn(_, entry) {
            search_state.stats.total_nodes_searched - entry.last_accessed
            <= max_recency
          })
      }
      SearchState(
        ..search_state,
        transposition:,
        stats: SearchStats(
          ..search_state.stats,
          tt_prunes: search_state.stats.tt_prunes + 1,
        ),
      )
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
  SearchStats(
    // The total amount of nodes we searched across the lifecycle of an entire
    // game.
    total_nodes_searched: Int,
    // At what amount of nodes searched did we start the current search?
    nodes_searched: Int,
    // When did we start the current search?
    init_time: timestamp.Timestamp,
    // Transposition table hits
    tt_hits: Int,
    // Transposition table misses
    tt_misses: Int,
    // Number of times we had to prune
    tt_prunes: Int,
    // How many beta cutoffs we did per depth
    beta_cutoffs: dict.Dict(Int, Int),
  )
}

pub fn stats_increment_nodes_searched() -> State(SearchState, Nil) {
  use search_state: SearchState <- state.modify
  let stats = search_state.stats
  SearchState(
    ..search_state,
    stats: SearchStats(
      ..stats,
      total_nodes_searched: stats.total_nodes_searched + 1,
      nodes_searched: stats.nodes_searched + 1,
    ),
  )
}

pub fn stats_add_beta_cutoffs(depth, n) -> State(SearchState, Nil) {
  use search_state: SearchState <- state.modify
  let stats = search_state.stats
  let beta_cutoffs = {
    use maybe_old_n <- dict.upsert(stats.beta_cutoffs, depth)
    case maybe_old_n {
      Some(old_n) -> old_n + n
      None -> n
    }
  }
  SearchState(..search_state, stats: SearchStats(..stats, beta_cutoffs:))
}

/// "Zero" out the stats. This should be done only at the start of a search.
/// The only thing that's left untouched is `total_nodes_searched` which is
/// currently still needed for transposition table pruning.
///
pub fn stats_zero(now: timestamp.Timestamp) -> State(SearchState, Nil) {
  use search_state: SearchState <- state.modify
  let stats =
    SearchStats(
      init_time: now,
      total_nodes_searched: search_state.stats.total_nodes_searched,
      nodes_searched: 0,
      tt_hits: 0,
      tt_misses: 0,
      tt_prunes: 0,
      beta_cutoffs: dict.new(),
    )
  SearchState(..search_state, stats:)
}

fn int_to_kilos(n: Int) {
  let ks = n / 1000
  let pt = n % 1000
  int.to_string(ks) <> "." <> int.to_string(pt) <> "K"
}

fn int_to_friendly_string(n: Int) {
  case n > 1000 {
    True -> int_to_kilos(n)
    False -> int.to_string(n)
  }
}

pub fn stats_to_string(
  search_state: SearchState,
  now: timestamp.Timestamp,
) -> String {
  let transposition = search_state.transposition
  let stats = search_state.stats
  let nps = stats_nodes_per_second(search_state, now)
  ""
  <> "Search Stats:\n"
  <> "  NPS: "
  <> nps |> float.round |> int_to_friendly_string
  <> "\n"
  <> "  Nodes: "
  <> stats.nodes_searched |> int_to_friendly_string
  <> "\n"
  <> "  TT size: "
  <> dict.size(transposition) |> int_to_friendly_string
  <> "\n"
  <> {
    "  TT hits/misses/%: "
    <> int_to_friendly_string(stats.tt_hits)
    <> "/"
    <> int_to_friendly_string(stats.tt_misses)
    <> "/"
    <> float.to_string(float.to_precision(
      int.to_float(stats.tt_hits)
        *. 100.0
        /. int.to_float(stats.tt_hits + stats.tt_misses),
      2,
    ))
    <> "%"
    <> "\n"
  }
  <> "  TT prunes: "
  <> stats.tt_prunes |> int_to_friendly_string
  <> "\n"
  <> {
    "  Beta cutoffs:"
    <> "\n    "
    <> dict.to_list(stats.beta_cutoffs)
    |> list.sort(fn(x, y) { int.compare(y.0, x.0) })
    |> list.map(fn(x) {
      "Depth " <> int.to_string(x.0) <> ": " <> int_to_friendly_string(x.1)
    })
    |> string.join("\n    ")
    <> "\n"
  }
}

pub fn stats_nodes_per_second(
  search_state: SearchState,
  now: timestamp.Timestamp,
) -> Float {
  let stats = search_state.stats
  let assert Ok(dt) =
    stats_delta_time_ms(search_state, now)
    |> int.to_float
    |> float.divide(1000.0)

  case dt {
    0.0 -> 1.0
    _ -> {
      let assert Ok(nps) =
        stats.nodes_searched
        |> int.to_float
        |> float.divide(dt)
      nps
    }
  }
}

pub fn stats_delta_time_ms(
  search_state: SearchState,
  now: timestamp.Timestamp,
) -> Int {
  let duration = timestamp.difference(search_state.stats.init_time, now)
  let #(s, ns) = duration.to_seconds_and_nanoseconds(duration)
  { s * 1000 } + { ns / 1_000_000 }
}
