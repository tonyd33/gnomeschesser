import chess/evaluate/common
import chess/evaluate/midgame
import chess/evaluate/mobility
import chess/game
import chess/player
import gleam/float
import gleam/int
import util/xint.{type ExtendedInt}

pub type Score =
  ExtendedInt

const material_weight = 85.0

const psqt_weight = 40.0

const mobility_weight = 45.0

const king_pawn_shield_weight = 4.0

const tempo_weight = 85.0

/// Evaluates the score of the game position
/// > 0 means white is winning
/// < 0 means black is winning
///
pub fn game(game: game.Game) -> Score {
  let game.EvaluationData(npm:, material_mg:, material_eg:, psqt_mg:, psqt_eg:) =
    game.evaluation_data(game)
  let phase = phase(npm)
  // only the mobility iterates through the pieces right now, so we can do this
  let mobility = mobility.score(game, phase)
  let material =
    common.taper(int.to_float(material_mg), int.to_float(material_eg), phase)
  let psq = common.taper(int.to_float(psqt_mg), int.to_float(psqt_eg), phase)

  let king_pawn_shield =
    midgame.king_pawn_shield(game, player.White)
    + midgame.king_pawn_shield(game, player.Black)
    |> int.to_float

  let tempo = 28.0 *. int.to_float(common.player(game.turn(game)))

  // combine scores with weight
  let score =
    {
      { material *. material_weight }
      +. { psq *. psqt_weight }
      +. { mobility *. mobility_weight }
      +. { king_pawn_shield *. king_pawn_shield_weight }
      +. { tempo *. tempo_weight }
    }
    /. {
      material_weight
      +. psqt_weight
      +. mobility_weight
      +. king_pawn_shield_weight
      +. tempo_weight
    }
  score
  |> float.truncate
  |> xint.from_int
}

/// Returns a value 0-1 such that:
/// - A value of 0.0 means we're completely in the endgame
/// - A value of 1.0 means we're completely in the midgame (or before it)
/// - A value in between signifies the weight endgame should be given, scaling
///   linearly.
///
pub fn phase(npm: Int) -> Float {
  // We'll calculate a measure, clamp them between two bounds, and then treat
  // it as the interpolated value between midgame and endgame after scaling.
  //
  // Endgame limit                                              Midgame limit
  //       v                                                          v
  //       |=========== * ============================================|
  //       ^            ^                                             ^
  //       0         measure                                         1
  //
  // We'll use a simple measure: non-pawn material value (npm). Pawns often get
  // traded back and forth in the midgame, and it's usually only approaching
  // the endgame that non-pawns start to be taken.
  //
  // This follows a similar strategy as Stockfish and gives a pretty similar
  // result. (note they scale from 0-128)
  // See: https://hxim.github.io/Stockfish-Evaluation-Guide/

  { { int.to_float(npm) -. endgame_limit } /. range_limit }
  |> float.clamp(0.0, 1.0)
}

const range_limit = 11_343.0

const endgame_limit = 3915.0

pub const player = common.player
