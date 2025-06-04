import chess/evaluate/common.{type SidedScore, SidedScore}
import chess/evaluate/midgame
import chess/evaluate/mobility
import chess/evaluate/psqt
import chess/game
import chess/piece
import chess/player
import gleam/int
import gleam/list
import util/xint.{type ExtendedInt}

pub type Score =
  ExtendedInt

/// Evaluates the score of the game position
/// > 0 means white is winning
/// < 0 means black is winning
///
pub fn game(game: game.Game) -> Score {
  let BatchedScores(
    npm,
    material_mg:,
    material_eg:,
    psq_mg:,
    psq_eg:,
    mobility_mg:,
    mobility_eg:,
  ) = compute_batched_scores(game)
  let phase = phase(npm)
  let material = taper(material_mg, material_eg, phase)
  let psq = taper(psq_mg, psq_eg, phase)
  let mobility = taper(mobility_mg, mobility_eg, phase)

  let king_safety_score =
    midgame.king_pawn_shield(game, player.White)
    + midgame.king_pawn_shield(game, player.Black)
  // combine scores with weight
  {
    {
      { material * 850 }
      + { psq * 850 }
      + { mobility * 850 }
      + { king_safety_score * 40 }
    }
    / { 850 + 850 + 850 + 40 }
  }
  |> xint.from_int
}

/// Returns a value 0-100 such that:
/// - A value of 0 means we're completely in the endgame
/// - A value of 100 means we're completely in the midgame (or before it)
/// - A value in between signifies the weight endgame should be given, scaling
///   linearly.
///
pub fn phase(npm_score: Int) -> Int {
  // We'll calculate a measure, clamp them between two bounds, and then treat
  // it as the interpolated value between midgame and endgame after scaling.
  //
  // Endgame limit                                              Midgame limit
  //       v                                                          v
  //       |=========== * ============================================|
  //       ^            ^                                             ^
  //       0         measure                                         100
  //
  // We'll use a simple measure: non-pawn material value (npm). Pawns often get
  // traded back and forth in the midgame, and it's usually only approaching
  // the endgame that non-pawns start to be taken.
  //
  // This follows a similar strategy as Stockfish and gives a pretty similar
  // result. (note they scale from 0-128)
  // See: https://hxim.github.io/Stockfish-Evaluation-Guide/

  let midgame_limit = 15_258
  let endgame_limit = 3915

  let npm =
    npm_score
    |> int.max(endgame_limit)
    |> int.min(midgame_limit)
  { { npm - endgame_limit } * 100 } / { midgame_limit - endgame_limit }
}

/// Make a smooth transition between mg and eg scores by phase.
///
fn taper(mg: Int, eg: Int, phase: Int) {
  { { mg * phase } + { eg * { 100 - phase } } } / 100
}

pub const player = common.player

/// A dummy data structure to hold all our scores as we traverse the board
/// in a single iteration for efficiency.
///
pub type BatchedScores {
  BatchedScores(
    npm: Int,
    material_mg: Int,
    material_eg: Int,
    psq_mg: Int,
    psq_eg: Int,
    mobility_mg: Int,
    mobility_eg: Int,
  )
}

const empty_batched_scores = BatchedScores(
  npm: 0,
  material_mg: 0,
  material_eg: 0,
  psq_mg: 0,
  psq_eg: 0,
  mobility_mg: 0,
  mobility_eg: 0,
)

fn add_batched_scores(s1: BatchedScores, s2: BatchedScores) {
  BatchedScores(
    npm: s1.npm + s2.npm,
    material_mg: s1.material_mg + s2.material_mg,
    material_eg: s1.material_eg + s2.material_eg,
    psq_mg: s1.psq_mg + s2.psq_mg,
    psq_eg: s1.psq_eg + s2.psq_eg,
    mobility_mg: s1.mobility_mg + s2.mobility_mg,
    mobility_eg: s1.mobility_eg + s2.mobility_eg,
  )
}

fn compute_batched_scores_at(white_controls, black_controls, square, piece) {
  let nmoves = case piece {
    piece.Piece(_, piece.Pawn) -> 0
    piece.Piece(_, piece.King) -> 0
    piece.Piece(player.White, _) -> white_controls(square, piece)
    piece.Piece(player.Black, _) -> black_controls(square, piece)
  }

  let material_mg = common.piece_symbol_mg(piece.symbol)
  //common.piece_symbol_eg(piece.symbol)
  let material_eg = material_mg

  let npm = common.piece_symbol_npm(piece.symbol)

  let player = piece.player |> common.player

  BatchedScores(
    npm:,
    material_mg: material_mg * player,
    material_eg: material_eg * player,
    psq_mg: psqt.score(piece, square, common.MidGame),
    psq_eg: psqt.score(piece, square, common.EndGame),
    mobility_mg: mobility.score(nmoves, piece, common.MidGame),
    mobility_eg: mobility.score(nmoves, piece, common.EndGame),
  )
}

pub fn compute_batched_scores(game: game.Game) {
  let white_controls = game.set_turn(game, player.White) |> game.controls
  let black_controls = game.set_turn(game, player.Black) |> game.controls

  use total_score, #(square, piece) <- list.fold(
    game.pieces(game),
    empty_batched_scores,
  )
  compute_batched_scores_at(white_controls, black_controls, square, piece)
  |> add_batched_scores(total_score)
}
