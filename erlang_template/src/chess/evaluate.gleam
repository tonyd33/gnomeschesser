import chess/game
import chess/piece
import chess/player
import gleam/float
import gleam/list
import gleam_community/maths

// Evaluates the score of the game position
// +1 is white
// -1 is black
// Scaled from -1 to +1
pub fn game(game: game.Game) -> Float {
  // evaluate material score
  let material_score =
    game.pieces(game)
    |> list.map(fn(square_piece) { piece(square_piece.1) })
    |> list.fold(0.0, float.add)

  // combine scores with weight
  { material_score *. 1.0 }
  // scale from -1.0 to 1.0
  |> fn(score) { maths.atan(score /. 4.0) *. 2.0 /. maths.pi() }
}

// Piece score based on player side
fn piece(piece: piece.Piece) -> Float {
  case piece.symbol {
    piece.Pawn -> 1.0
    piece.Knight -> 3.0
    piece.Bishop -> 3.0
    piece.Rook -> 5.0
    piece.Queen -> 9.0
    piece.King -> 0.0
  }
  *. player(piece.player)
}

// The sign of each player in evaluations
pub fn player(player: player.Player) -> Float {
  case player {
    player.White -> 1.0
    player.Black -> -1.0
  }
}
