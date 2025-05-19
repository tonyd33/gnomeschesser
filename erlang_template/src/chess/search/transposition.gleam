import chess/game
import chess/search/evaluation
import gleam/dict

/// A table to cache calculation results.
///
pub type Table =
  dict.Dict(game.Hash, Entry)

/// We also store "when" an entry was last accessed so we can prune it if need be.
/// "when" should be any monotonic non-decreasing measure; time is an obvious
/// choice, but the number of nodes searched serves us just as well.
///
pub type Entry {
  Entry(
    depth: evaluation.Depth,
    eval: evaluation.Evaluation,
    last_accessed: Int,
  )
}

pub fn new() -> Table {
  dict.new()
}
