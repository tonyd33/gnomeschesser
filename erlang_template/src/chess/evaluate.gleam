import chess/game
import chess/piece
import chess/player
import chess/psqt
import gleam/float
import gleam/int
import gleam/list
import gleam_community/maths
import util/xint.{type ExtendedInt}

/// Evaluates the score of the game position
/// > 0 means white is winning
/// < 0 means black is winning
/// Scaled from -1 to +1
///
pub fn game(game: game.Game) -> ExtendedInt {
  let us = game.turn(game)

  // evaluate material score
  let material_score =
    game.pieces(game)
    |> list.map(fn(square_piece) { piece(square_piece.1) })
    |> list.fold(0, int.add)
    |> int.multiply(200_000)

  let pqst_score = {
    let pieces = game.pieces(game)
    let game_stage = case
      list.filter(pieces, fn(x) { { x.1 }.symbol == piece.Queen })
    {
      [] -> psqt.EndGame
      _ -> psqt.MidGame
    }
    pieces
    |> list.map(fn(square_pieces) {
      psqt.get_psq_score(square_pieces.1, square_pieces.0, game_stage)
    })
    |> list.fold(0, int.add)
    |> int.multiply(2000)
  }

  // TODO: DON'T CALL MOVES HERE! IT'S (relatively) EXPENSIVE STILL!
  //       We may have the callee pass in the moves since the callee is likely
  //       to calculate this anyway. Or, we may create another function in
  //       `game` to optimize for our use case
  let moves = game.pseudolegal_moves(game)

  // Calculate a [mobility score](https://www.chessprogramming.org/Mobility).
  //
  // Roughly, we want to capture the idea that "the more choices we have at
  // our disposal, the stronger our position."
  //
  // This is implemented in a similar fashion: for every move, it counts
  // positively towards the mobility score and is weighted by the piece.
  let mobility_score =
    moves
    |> list.fold(0, fn(mobility_score, move) {
      let s = case game.move_piece(move) {
        piece.Pawn -> 0
        piece.Knight -> 0
        piece.Bishop -> 458_758
        piece.Rook -> 262_147
        piece.Queen -> 196_611
        piece.King -> -10
      }
      mobility_score + s
    })
    |> int.multiply(player(us))

  // combine scores with weight
  { material_score * 900 + mobility_score * 50 + pqst_score * 50 }
  |> xint.from_int
}

// Piece score based on player side
fn piece(piece: piece.Piece) -> Int {
  case piece.symbol {
    piece.Pawn -> 1
    piece.Knight -> 3
    piece.Bishop -> 3
    piece.Rook -> 5
    piece.Queen -> 9
    piece.King -> 0
  }
  * player(piece.player)
}

// The sign of each player in evaluations
pub fn player(player: player.Player) -> Int {
  case player {
    player.White -> 1
    player.Black -> -1
  }
}
