import chess/piece
import chess/search/evaluation.{type Evaluation, Evaluation}
import chess/search/transposition
import chess/square
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import iv
import util/state.{type State, State}

pub type Cluster {
  Cluster(
    always_replace: Option(transposition.Entry),
    depth_preferred: Option(transposition.Entry),
  )
}

const empty_cluster = Cluster(None, None)

pub type SearchState {
  SearchState(
    // always-replace, depth-preferred
    transposition: iv.Array(Cluster),
    history: dict.Dict(#(square.Square, piece.Piece), Int),
    cycle: Int,
    stats: SearchStats,
  )
}

pub fn new(now: timestamp.Timestamp) {
  SearchState(
    transposition: iv.repeat(empty_cluster, key_size + 1),
    history: dict.new(),
    cycle: 0,
    stats: SearchStats(
      iteration_depth: 0,
      total_nodes_searched: 0,
      nodes_searched: 0,
      init_time: now,
      tt_hits: 0,
      tt_misses: 0,
      tt_size: 0,
      beta_cutoffs: dict.new(),
      rfp_cutoffs: dict.new(),
      nmp_cutoffs: dict.new(),
      iid_triggers: dict.new(),
      lmrs: dict.new(),
      lmr_verifications: dict.new(),
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
/// large, we reduce the key space by modding out by this key size.
const key_size = 100_000

fn transposition_key_reduce(key: Int) {
  key % key_size
}

fn cluster_get(cluster: Cluster, hash: Int) {
  case cluster {
    Cluster(Some(always_replace), Some(depth_preferred))
      if always_replace.hash == hash && depth_preferred.hash == hash
    ->
      // Both entry have the same hash. Break the tie by depth
      case always_replace.depth > depth_preferred.depth {
        True -> Ok(always_replace)
        False -> Ok(depth_preferred)
      }
    Cluster(Some(always_replace), _) if always_replace.hash == hash ->
      Ok(always_replace)
    Cluster(_, Some(depth_preferred)) if depth_preferred.hash == hash ->
      Ok(depth_preferred)
    Cluster(None, None) -> Error(Nil)
    _ -> Error(Nil)
  }
}

fn cluster_insert(
  cluster: Cluster,
  hash: Int,
  prospective_entry: transposition.Entry,
) {
  let is_new_entry = option.is_none(cluster.always_replace)
  let always_replace = prospective_entry
  let depth_preferred = case cluster.depth_preferred {
    Some(depth_preferred) -> {
      let is_pv = prospective_entry.eval.node_type == evaluation.PV
      let pv_num = case is_pv {
        True -> 1
        False -> 0
      }
      // Update the transposition table if:
      // - The new entry is a PV, or
      // - The new entry replaces the existing hash, or
      // - The new entry is considerably deeper than the existing entry's depth
      //   (depth-preferred)
      let override =
        is_pv
        || depth_preferred.hash != hash
        // Consider the entry to be deeper if it's PV
        || prospective_entry.depth + { 2 * pv_num } > depth_preferred.depth + 2
      case override {
        True -> prospective_entry
        False -> depth_preferred
      }
    }
    None -> prospective_entry
  }
  #(Cluster(Some(always_replace), Some(depth_preferred)), is_new_entry)
}

pub fn transposition_get(
  hash: Int,
) -> State(SearchState, Result(transposition.Entry, Nil)) {
  use search_state: SearchState <- State(run: _)
  let transposition = search_state.transposition
  let key = transposition_key_reduce(hash)
  let assert Ok(cluster) = iv.get(transposition, key)
  let entry = case cluster {
    Cluster(_, Some(depth_preferred)) if depth_preferred.hash == hash ->
      Ok(depth_preferred)
    Cluster(Some(always_replace), Some(depth_preferred))
      if always_replace.hash == hash && depth_preferred.hash == hash
    ->
      // Both entry have the same hash. Break the tie by depth
      case always_replace.depth > depth_preferred.depth {
        True -> Ok(always_replace)
        False -> Ok(depth_preferred)
      }
    Cluster(Some(always_replace), _) if always_replace.hash == hash ->
      Ok(always_replace)
    Cluster(None, None) -> Error(Nil)
    _ -> Error(Nil)
  }

  case entry {
    Ok(entry) -> {
      #(
        Ok(entry),
        SearchState(
          ..search_state,
          stats: SearchStats(
            ..search_state.stats,
            tt_hits: search_state.stats.tt_hits + 1,
          ),
        ),
      )
    }
    Error(Nil) -> #(
      Error(Nil),
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
  let entry = transposition.Entry(hash:, depth:, eval:, age: search_state.cycle)
  let key = transposition_key_reduce(hash)

  let assert Ok(cluster) = iv.get(search_state.transposition, key)
  let #(cluster, is_new_entry) = {
    let is_new_entry = option.is_none(cluster.always_replace)
    let always_replace = entry
    let depth_preferred = case cluster.depth_preferred {
      Some(depth_preferred) -> {
        let is_pv = entry.eval.node_type == evaluation.PV
        let pv_num = case is_pv {
          True -> 1
          False -> 0
        }
        // Update the transposition table if:
        // - The new entry is a PV, or
        // - The new entry replaces the existing hash, or
        // - The new entry is considerably deeper than the existing entry's depth
        //   (depth-preferred)
        let override =
          is_pv
          || depth_preferred.hash != hash
          // Consider the entry to be deeper if it's PV
          || entry.depth + { 2 * pv_num } > depth_preferred.depth + 2
        case override {
          True -> entry
          False -> depth_preferred
        }
      }
      None -> entry
    }
    #(Cluster(Some(always_replace), Some(depth_preferred)), is_new_entry)
  }
  let assert Ok(transposition) =
    iv.set(search_state.transposition, key, cluster)

  case is_new_entry {
    True ->
      SearchState(
        ..search_state,
        transposition:,
        stats: SearchStats(
          ..search_state.stats,
          tt_size: search_state.stats.tt_size + 1,
        ),
      )
    False -> SearchState(..search_state, transposition:)
  }
}

pub type SearchStats {
  SearchStats(
    // What iteration of iterative deepening are we on right now?
    iteration_depth: Int,
    // The total amount of nodes we searched across the lifecycle of an entire
    // game.
    total_nodes_searched: Int,
    // At what amount of nodes searched did we start the current search?
    nodes_searched: Int,
    // When did we start the current search?
    init_time: timestamp.Timestamp,
    // Transposition table size
    tt_size: Int,
    // Transposition table hits
    tt_hits: Int,
    // Transposition table misses
    tt_misses: Int,
    // How many regular beta cutoffs we did per depth
    beta_cutoffs: dict.Dict(Int, Int),
    // How many reverse futility pruning cutoffs we did per depth
    rfp_cutoffs: dict.Dict(Int, Int),
    // How many null move pruning cutoffs we did per depth
    nmp_cutoffs: dict.Dict(Int, Int),
    // How many times IID was triggered per depth
    iid_triggers: dict.Dict(Int, Int),
    // How many times late move reductions was triggered per depth
    lmrs: dict.Dict(Int, Int),
    // How many times we had to re search when LMR failed high per depth
    lmr_verifications: dict.Dict(Int, Int),
  )
}

pub fn stats_set_iteration_depth(iteration_depth) {
  use search_state: SearchState <- state.modify

  SearchState(
    ..search_state,
    stats: SearchStats(..search_state.stats, iteration_depth:),
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

pub fn stats_increment_iid_triggers(depth) -> State(SearchState, Nil) {
  use search_state: SearchState <- state.modify
  let stats = search_state.stats
  let iid_triggers = {
    use maybe_old_n <- dict.upsert(stats.iid_triggers, depth)
    case maybe_old_n {
      Some(old_n) -> old_n + 1
      None -> 1
    }
  }
  SearchState(..search_state, stats: SearchStats(..stats, iid_triggers:))
}

pub fn stats_increment_lmrs(depth) -> State(SearchState, Nil) {
  use search_state: SearchState <- state.modify
  let stats = search_state.stats
  let lmrs = {
    use maybe_old_n <- dict.upsert(stats.lmrs, depth)
    case maybe_old_n {
      Some(old_n) -> old_n + 1
      None -> 1
    }
  }
  SearchState(..search_state, stats: SearchStats(..stats, lmrs:))
}

pub fn stats_increment_lmr_verifications(depth) -> State(SearchState, Nil) {
  use search_state: SearchState <- state.modify
  let stats = search_state.stats
  let lmr_verifications = {
    use maybe_old_n <- dict.upsert(stats.lmr_verifications, depth)
    case maybe_old_n {
      Some(old_n) -> old_n + 1
      None -> 1
    }
  }
  SearchState(..search_state, stats: SearchStats(..stats, lmr_verifications:))
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

pub fn stats_add_rfp_cutoffs(depth, n) -> State(SearchState, Nil) {
  use search_state: SearchState <- state.modify
  let stats = search_state.stats
  let rfp_cutoffs = {
    use maybe_old_n <- dict.upsert(stats.rfp_cutoffs, depth)
    case maybe_old_n {
      Some(old_n) -> old_n + n
      None -> n
    }
  }
  SearchState(..search_state, stats: SearchStats(..stats, rfp_cutoffs:))
}

pub fn stats_add_nmp_cutoffs(depth, n) -> State(SearchState, Nil) {
  use search_state: SearchState <- state.modify
  let stats = search_state.stats
  let nmp_cutoffs = {
    use maybe_old_n <- dict.upsert(stats.nmp_cutoffs, depth)
    case maybe_old_n {
      Some(old_n) -> old_n + n
      None -> n
    }
  }
  SearchState(..search_state, stats: SearchStats(..stats, nmp_cutoffs:))
}

/// "Zero" out the stats. This should be done only at the start of a search.
///
pub fn stats_zero(now: timestamp.Timestamp) -> State(SearchState, Nil) {
  use search_state: SearchState <- state.modify
  let stats =
    SearchStats(
      iteration_depth: 0,
      init_time: now,
      total_nodes_searched: search_state.stats.total_nodes_searched,
      nodes_searched: 0,
      tt_hits: 0,
      tt_misses: 0,
      tt_size: search_state.stats.tt_size,
      beta_cutoffs: dict.new(),
      rfp_cutoffs: dict.new(),
      nmp_cutoffs: dict.new(),
      iid_triggers: dict.new(),
      lmrs: dict.new(),
      lmr_verifications: dict.new(),
    )
  SearchState(..search_state, cycle: search_state.cycle + 1, stats:)
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

fn per_depth_stats(name: String, per_depth: dict.Dict(Int, Int)) {
  "  "
  <> name
  <> ":"
  <> case dict.is_empty(per_depth) {
    True -> " none"
    False -> {
      "\n    "
      <> dict.to_list(per_depth)
      |> list.sort(fn(x, y) { int.compare(y.0, x.0) })
      |> list.map(fn(x) {
        "Depth " <> int.to_string(x.0) <> ": " <> int_to_friendly_string(x.1)
      })
      |> string.join("\n    ")
    }
  }
}

pub fn stats_to_string(stats: SearchStats, now: timestamp.Timestamp) -> String {
  let nps = stats_nodes_per_second(stats, now)
  let dt = stats_delta_time_ms(stats, now)
  ""
  <> "Search Stats:\n"
  <> "  Depth: "
  <> int.to_string(stats.iteration_depth)
  <> "\n"
  <> "  Time: "
  <> int.to_string(dt)
  <> "ms"
  <> "\n"
  <> "  NPS: "
  <> nps |> float.round |> int_to_friendly_string
  <> "\n"
  <> "  Total nodes: "
  <> stats.total_nodes_searched |> int_to_friendly_string
  <> "\n"
  <> "  Nodes: "
  <> stats.nodes_searched |> int_to_friendly_string
  <> "\n"
  <> "  TT size: "
  <> stats.tt_size |> int_to_friendly_string
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
  }
  <> "\n"
  <> per_depth_stats("Beta cutoffs", stats.beta_cutoffs)
  <> "\n"
  <> per_depth_stats("RFP cutoffs", stats.rfp_cutoffs)
  <> "\n"
  <> per_depth_stats("NMP cutoffs", stats.nmp_cutoffs)
  <> "\n"
  <> per_depth_stats("IID triggers", stats.iid_triggers)
  <> "\n"
  <> per_depth_stats("LMRs", stats.lmrs)
  <> "\n"
  <> per_depth_stats("LMR verifications", stats.lmr_verifications)
  <> "\n"
}

pub fn stats_nodes_per_second(
  stats: SearchStats,
  now: timestamp.Timestamp,
) -> Float {
  let assert Ok(dt) =
    stats_delta_time_ms(stats, now)
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

pub fn stats_delta_time_ms(stats: SearchStats, now: timestamp.Timestamp) -> Int {
  let duration = timestamp.difference(stats.init_time, now)
  let #(s, ns) = duration.to_seconds_and_nanoseconds(duration)
  { s * 1000 } + { ns / 1_000_000 }
}

pub fn stats_hashfull(stats: SearchStats) -> Int {
  let size = stats.tt_size
  float.round({ int.to_float(size) *. 1000.0 } /. int.to_float(key_size))
}
