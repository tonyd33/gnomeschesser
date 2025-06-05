import chess/evaluate
import chess/move
import gleam/option
import util/xint

pub type Depth =
  Int

pub type Evaluation {
  Evaluation(
    score: evaluate.Score,
    node_type: NodeType,
    best_move: option.Option(move.Move(move.ValidInContext)),
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

pub fn negate(evaluation: Evaluation) -> Evaluation {
  let node_type = case evaluation.node_type {
    Cut -> All
    All -> Cut
    PV -> PV
  }
  let score = xint.negate(evaluation.score)
  Evaluation(..evaluation, score:, node_type:)
}
