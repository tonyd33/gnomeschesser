import chess/evaluate/common
import chess/evaluate/endgame
import chess/evaluate/midgame
import chess/game
import chess/piece
import chess/player
import gleam/dict
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
  let board = game.board(game)
  let pieces = game.pieces(game)
  // TODO: use a cached version of getting moves somehow?
  let our_moves = game.valid_moves(game)

  let scores = batch_scores(game)
  let phase = phase(game, scores)

  // evaluate material score
  // TODO: we can combine the material score with the PSQT to squeeze out performance
  // but we could just do that at the very end after we tune it
  let #(material_score, _, _) = scores

  let mg_pqst = midgame.psqt(pieces) * phase
  let eg_pqst = endgame.psqt(pieces) * { 100 - phase }
  let pqst_score = { mg_pqst + eg_pqst } / 100

  // TODO: change these based on the state of the game
  let mobility_score = midgame.mobility(our_moves)
  let king_safety_score =
    midgame.king_pawn_shield(game, player.White)
    + midgame.king_pawn_shield(game, player.Black)
  // combine scores with weight
  {
    {
      { material_score * 850 }
      + { mobility_score * 10 }
      + { pqst_score * 50 }
      + { king_safety_score * 40 }
    }
    / { 850 + 10 + 50 + 40 }
  }
  |> xint.from_int
}

/// Returns a value 0-100 such that:
/// - A value of 0 means we're completely in the endgame
/// - A value of 100 means we're completely in the midgame (or before it)
/// - A value in between signifies the weight endgame should be given, scaling
///   linearly.
/// This is closely tied to the values in common.gleam!!
///
pub fn phase(game: game.Game, scores: #(Int, Int, Int)) -> Int {
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
  // result. (note they scale from 0-128).
  // See: https://hxim.github.io/Stockfish-Evaluation-Guide/

  let #(_, npm_white, npm_black) = scores

  let midgame_limit = 15_258
  let endgame_limit = 3915

  let npm =
    { npm_white + npm_black }
    |> int.max(endgame_limit)
    |> int.min(midgame_limit)
  { { npm - endgame_limit } * 100 } / { midgame_limit - endgame_limit }
}

pub fn batch_scores(game: game.Game) {
  let #(material_score, npm_white, npm_black) =
    game.pieces(game)
    |> list.fold(#(0, 0, 0), fn(acc, square_piece) {
      let #(material_score, npm_white, npm_black) = acc
      let #(square, piece) = square_piece

      let #(material_score_p, npm_white_p, npm_black_p) = case piece {
        piece.Piece(_, piece.Pawn) -> #(common.piece(piece), 0, 0)
        piece.Piece(player.White, symbol) -> #(
          common.piece(piece),
          common.piece_value_bonus(symbol, common.MidGame),
          0,
        )
        piece.Piece(player.Black, symbol) -> #(
          common.piece(piece),
          0,
          common.piece_value_bonus(symbol, common.MidGame),
        )
      }
      #(
        material_score + material_score_p,
        npm_white + npm_white_p,
        npm_black + npm_black_p,
      )
    })
}

pub const piece_symbol = common.piece_symbol

pub const player = common.player
