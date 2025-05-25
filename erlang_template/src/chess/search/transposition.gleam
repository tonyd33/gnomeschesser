import chess/search/evaluation
import gleam/dict

/// A table to cache calculation results.
///
pub type Table =
  dict.Dict(Int, Entry)

/// We also store "when" an entry was last accessed so we can prune it if need be.
/// "when" should be any monotonic non-decreasing measure; time is an obvious
/// choice, but the number of nodes searched serves us just as well.
///
pub type Entry {
  Entry(
    hash: Int,
    depth: evaluation.Depth,
    eval: evaluation.Evaluation,
  )
}

pub fn new() -> Table {
  dict.new()
}
