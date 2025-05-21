import chess/evaluate/common
import chess/evaluate/endgame
import chess/evaluate/midgame
import chess/game
import chess/piece
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
  let us = game.turn(game)
  let pieces = game.pieces(game)
  // TODO: use a cached version of getting moves somehow?
  let valid_moves = game.valid_moves(game)

  let game_stage = case
    pieces
    |> list.filter(fn(x) { { x.1 }.symbol == piece.Queen })
  {
    [] -> common.EndGame
    _ -> common.MidGame
  }

  // evaluate material score
  let material_score =
    game.pieces(game)
    |> list.map(fn(square_piece) { common.piece(square_piece.1) })
    |> list.fold(0, int.add)
  let pqst_score = case game_stage {
    common.MidGame -> midgame.psqt(pieces)
    common.EndGame -> endgame.psqt(pieces)
  }
  // TODO: change these based on the state of the game
  let mobility_score = midgame.mobility(valid_moves, us)
  let king_safety_score = midgame.king_pawn_shield(game)

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
