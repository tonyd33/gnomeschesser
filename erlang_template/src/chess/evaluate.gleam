import chess/evaluate/common
import chess/evaluate/endgame
import chess/evaluate/midgame
import chess/game
import chess/piece
import chess/player
import gleam/dict
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
  let moves = game.pseudolegal_moves(game)

  // TODO: scale this gradually
  let game_stage = case
    board
    |> dict.filter(fn(_square, piece) { piece.symbol == piece.Queen })
    |> dict.is_empty
  {
    True -> common.EndGame
    False -> common.MidGame
  }

  // evaluate material score
  // TODO: we can combine the material score with the PSQT to squeeze out performance
  // but we could just do that at the very end after we tune it
  let material_score =
    game.pieces(game)
    |> list.fold(0, fn(acc, square_piece) { common.piece(square_piece.1) + acc })

  let pqst_score = case game_stage {
    common.MidGame -> midgame.psqt(pieces)
    common.EndGame -> endgame.psqt(pieces)
  }
  // TODO: change these based on the state of the game
  let mobility_score = midgame.mobility(game, moves)
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

pub const piece_symbol = common.piece_symbol

pub const player = common.player
