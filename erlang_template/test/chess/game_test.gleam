import chess/game.{load_fen}
import chess/piece
import chess/player
import chess/square
import gleam/dict
import gleeunit/should

// See: https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation#Examples
pub fn load_fen_starting_position_test() {
  let assert Ok(game) =
    load_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

  game
  |> game.pieces
  |> dict.from_list
  |> should.equal(
    [
      #(square.A1, piece.Piece(player.White, piece.Rook)),
      #(square.B1, piece.Piece(player.White, piece.Knight)),
      #(square.C1, piece.Piece(player.White, piece.Bishop)),
      #(square.D1, piece.Piece(player.White, piece.Queen)),
      #(square.E1, piece.Piece(player.White, piece.King)),
      #(square.F1, piece.Piece(player.White, piece.Bishop)),
      #(square.G1, piece.Piece(player.White, piece.Knight)),
      #(square.H1, piece.Piece(player.White, piece.Rook)),
      #(square.A2, piece.Piece(player.White, piece.Pawn)),
      #(square.B2, piece.Piece(player.White, piece.Pawn)),
      #(square.C2, piece.Piece(player.White, piece.Pawn)),
      #(square.D2, piece.Piece(player.White, piece.Pawn)),
      #(square.E2, piece.Piece(player.White, piece.Pawn)),
      #(square.F2, piece.Piece(player.White, piece.Pawn)),
      #(square.G2, piece.Piece(player.White, piece.Pawn)),
      #(square.H2, piece.Piece(player.White, piece.Pawn)),
      #(square.A8, piece.Piece(player.Black, piece.Rook)),
      #(square.B8, piece.Piece(player.Black, piece.Knight)),
      #(square.C8, piece.Piece(player.Black, piece.Bishop)),
      #(square.D8, piece.Piece(player.Black, piece.Queen)),
      #(square.E8, piece.Piece(player.Black, piece.King)),
      #(square.F8, piece.Piece(player.Black, piece.Bishop)),
      #(square.G8, piece.Piece(player.Black, piece.Knight)),
      #(square.H8, piece.Piece(player.Black, piece.Rook)),
      #(square.A7, piece.Piece(player.Black, piece.Pawn)),
      #(square.B7, piece.Piece(player.Black, piece.Pawn)),
      #(square.C7, piece.Piece(player.Black, piece.Pawn)),
      #(square.D7, piece.Piece(player.Black, piece.Pawn)),
      #(square.E7, piece.Piece(player.Black, piece.Pawn)),
      #(square.F7, piece.Piece(player.Black, piece.Pawn)),
      #(square.G7, piece.Piece(player.Black, piece.Pawn)),
      #(square.H7, piece.Piece(player.Black, piece.Pawn)),
    ]
    |> dict.from_list,
  )

  game
  |> game.castling_availability
  |> dict.from_list
  |> should.equal(
    [
      #(player.White, game.KingSide),
      #(player.White, game.QueenSide),
      #(player.Black, game.KingSide),
      #(player.Black, game.QueenSide),
    ]
    |> dict.from_list,
  )
}

// See: https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation#Examples
pub fn load_fen_e4_test() {
  let assert Ok(game) =
    load_fen("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")

  game
  |> game.pieces
  |> dict.from_list
  |> should.equal(
    [
      #(square.A1, piece.Piece(player.White, piece.Rook)),
      #(square.B1, piece.Piece(player.White, piece.Knight)),
      #(square.C1, piece.Piece(player.White, piece.Bishop)),
      #(square.D1, piece.Piece(player.White, piece.Queen)),
      #(square.E1, piece.Piece(player.White, piece.King)),
      #(square.F1, piece.Piece(player.White, piece.Bishop)),
      #(square.G1, piece.Piece(player.White, piece.Knight)),
      #(square.H1, piece.Piece(player.White, piece.Rook)),
      #(square.A2, piece.Piece(player.White, piece.Pawn)),
      #(square.B2, piece.Piece(player.White, piece.Pawn)),
      #(square.C2, piece.Piece(player.White, piece.Pawn)),
      #(square.D2, piece.Piece(player.White, piece.Pawn)),
      #(square.E4, piece.Piece(player.White, piece.Pawn)),
      #(square.F2, piece.Piece(player.White, piece.Pawn)),
      #(square.G2, piece.Piece(player.White, piece.Pawn)),
      #(square.H2, piece.Piece(player.White, piece.Pawn)),
      #(square.A8, piece.Piece(player.Black, piece.Rook)),
      #(square.B8, piece.Piece(player.Black, piece.Knight)),
      #(square.C8, piece.Piece(player.Black, piece.Bishop)),
      #(square.D8, piece.Piece(player.Black, piece.Queen)),
      #(square.E8, piece.Piece(player.Black, piece.King)),
      #(square.F8, piece.Piece(player.Black, piece.Bishop)),
      #(square.G8, piece.Piece(player.Black, piece.Knight)),
      #(square.H8, piece.Piece(player.Black, piece.Rook)),
      #(square.A7, piece.Piece(player.Black, piece.Pawn)),
      #(square.B7, piece.Piece(player.Black, piece.Pawn)),
      #(square.C7, piece.Piece(player.Black, piece.Pawn)),
      #(square.D7, piece.Piece(player.Black, piece.Pawn)),
      #(square.E7, piece.Piece(player.Black, piece.Pawn)),
      #(square.F7, piece.Piece(player.Black, piece.Pawn)),
      #(square.G7, piece.Piece(player.Black, piece.Pawn)),
      #(square.H7, piece.Piece(player.Black, piece.Pawn)),
    ]
    |> dict.from_list,
  )

  game
  |> game.castling_availability
  |> dict.from_list
  |> should.equal(
    [
      #(player.White, game.KingSide),
      #(player.White, game.QueenSide),
      #(player.Black, game.KingSide),
      #(player.Black, game.QueenSide),
    ]
    |> dict.from_list,
  )
}

pub fn load_fen_fail_test() {
  // has an extra row
  let assert Error(_) =
    load_fen("/rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
  // has an extra piece
  let assert Error(_) =
    load_fen("prnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
  // has an extra row + piece
  let assert Error(_) =
    load_fen("p/rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
}
