import chess/evaluate/common
import chess/evaluate/midgame
import chess/evaluate/mobility
import chess/game
import chess/player
import gleam/int
import util/xint.{type ExtendedInt}

pub type Score =
  ExtendedInt

/// Evaluates the score of the game position
/// > 0 means white is winning
/// < 0 means black is winning
///
pub fn game(game: game.Game) -> Score {
  let game.EvaluationData(npm:, material_mg:, material_eg:, psqt_mg:, psqt_eg:) =
    game.evaluation_data(game)
  let phase = phase(npm)
  let material = common.taper(material_mg, material_eg, phase)
  let psq = common.taper(psqt_mg, psqt_eg, phase)
  // only the mobility iterates through the pieces right now, so we can do this
  let mobility = mobility.score(game, phase)

  let king_safety_score =
    midgame.king_pawn_shield(game, player.White)
    + midgame.king_pawn_shield(game, player.Black)

  // combine scores with weight

  let score =
    { material * 85 + psq * 85 + mobility * 85 + king_safety_score * 4 }
    / { 85 + 85 + 85 + 4 }
  xint.from_int(score)
}

/// Returns a value 0-100 such that:
/// - A value of 0 means we're completely in the endgame
/// - A value of 100 means we're completely in the midgame (or before it)
/// - A value in between signifies the weight endgame should be given, scaling
///   linearly.
///
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

  let npm = int.clamp(npm_score, endgame_limit, midgame_limit)
  { { npm - endgame_limit } * 100 } / { midgame_limit - endgame_limit }
}

const midgame_limit = 15_258

const endgame_limit = 3915

pub const player = common.player
