import erlang_template/chess.{Piece, load_fen}
import gleam/dict
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// See: https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation#Examples
pub fn load_fen_starting_position_test() {
  let assert Ok(game) =
    load_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

  let expected_cells =
    [
      #(chess.A1, Piece(chess.White, chess.Rook)),
      #(chess.B1, Piece(chess.White, chess.Knight)),
      #(chess.C1, Piece(chess.White, chess.Bishop)),
      #(chess.D1, Piece(chess.White, chess.Queen)),
      #(chess.E1, Piece(chess.White, chess.King)),
      #(chess.F1, Piece(chess.White, chess.Bishop)),
      #(chess.G1, Piece(chess.White, chess.Knight)),
      #(chess.H1, Piece(chess.White, chess.Rook)),
      #(chess.A2, Piece(chess.White, chess.Pawn)),
      #(chess.B2, Piece(chess.White, chess.Pawn)),
      #(chess.C2, Piece(chess.White, chess.Pawn)),
      #(chess.D2, Piece(chess.White, chess.Pawn)),
      #(chess.E2, Piece(chess.White, chess.Pawn)),
      #(chess.F2, Piece(chess.White, chess.Pawn)),
      #(chess.G2, Piece(chess.White, chess.Pawn)),
      #(chess.H2, Piece(chess.White, chess.Pawn)),
      #(chess.A8, Piece(chess.Black, chess.Rook)),
      #(chess.B8, Piece(chess.Black, chess.Knight)),
      #(chess.C8, Piece(chess.Black, chess.Bishop)),
      #(chess.D8, Piece(chess.Black, chess.Queen)),
      #(chess.E8, Piece(chess.Black, chess.King)),
      #(chess.F8, Piece(chess.Black, chess.Bishop)),
      #(chess.G8, Piece(chess.Black, chess.Knight)),
      #(chess.H8, Piece(chess.Black, chess.Rook)),
      #(chess.A7, Piece(chess.Black, chess.Pawn)),
      #(chess.B7, Piece(chess.Black, chess.Pawn)),
      #(chess.C7, Piece(chess.Black, chess.Pawn)),
      #(chess.D7, Piece(chess.Black, chess.Pawn)),
      #(chess.E7, Piece(chess.Black, chess.Pawn)),
      #(chess.F7, Piece(chess.Black, chess.Pawn)),
      #(chess.G7, Piece(chess.Black, chess.Pawn)),
      #(chess.H7, Piece(chess.Black, chess.Pawn)),
    ]
    |> dict.from_list

  game.board |> should.equal(expected_cells)
}

// See: https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation#Examples
pub fn load_fen_e4_test() {
  let assert Ok(game) =
    load_fen("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")

  let expected_cells =
    [
      #(chess.A1, Piece(chess.White, chess.Rook)),
      #(chess.B1, Piece(chess.White, chess.Knight)),
      #(chess.C1, Piece(chess.White, chess.Bishop)),
      #(chess.D1, Piece(chess.White, chess.Queen)),
      #(chess.E1, Piece(chess.White, chess.King)),
      #(chess.F1, Piece(chess.White, chess.Bishop)),
      #(chess.G1, Piece(chess.White, chess.Knight)),
      #(chess.H1, Piece(chess.White, chess.Rook)),
      #(chess.A2, Piece(chess.White, chess.Pawn)),
      #(chess.B2, Piece(chess.White, chess.Pawn)),
      #(chess.C2, Piece(chess.White, chess.Pawn)),
      #(chess.D2, Piece(chess.White, chess.Pawn)),
      #(chess.E4, Piece(chess.White, chess.Pawn)),
      #(chess.F2, Piece(chess.White, chess.Pawn)),
      #(chess.G2, Piece(chess.White, chess.Pawn)),
      #(chess.H2, Piece(chess.White, chess.Pawn)),
      #(chess.A8, Piece(chess.Black, chess.Rook)),
      #(chess.B8, Piece(chess.Black, chess.Knight)),
      #(chess.C8, Piece(chess.Black, chess.Bishop)),
      #(chess.D8, Piece(chess.Black, chess.Queen)),
      #(chess.E8, Piece(chess.Black, chess.King)),
      #(chess.F8, Piece(chess.Black, chess.Bishop)),
      #(chess.G8, Piece(chess.Black, chess.Knight)),
      #(chess.H8, Piece(chess.Black, chess.Rook)),
      #(chess.A7, Piece(chess.Black, chess.Pawn)),
      #(chess.B7, Piece(chess.Black, chess.Pawn)),
      #(chess.C7, Piece(chess.Black, chess.Pawn)),
      #(chess.D7, Piece(chess.Black, chess.Pawn)),
      #(chess.E7, Piece(chess.Black, chess.Pawn)),
      #(chess.F7, Piece(chess.Black, chess.Pawn)),
      #(chess.G7, Piece(chess.Black, chess.Pawn)),
      #(chess.H7, Piece(chess.Black, chess.Pawn)),
    ]
    |> dict.from_list

  game.board |> should.equal(expected_cells)
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
