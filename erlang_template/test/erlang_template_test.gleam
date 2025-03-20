import erlang_template/chess.{Board, Game, fen_to_game}
import gleam/dict
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// Examples taken from: https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation#Examples
pub fn fen_to_game_starting_position_test() {
  let Game(Board(cells)) =
    fen_to_game("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

  let expected_cells =
    [
      #(#(0, 0), #(chess.Rook, chess.White)),
      #(#(1, 0), #(chess.Knight, chess.White)),
      #(#(2, 0), #(chess.Bishop, chess.White)),
      #(#(3, 0), #(chess.Queen, chess.White)),
      #(#(4, 0), #(chess.King, chess.White)),
      #(#(5, 0), #(chess.Bishop, chess.White)),
      #(#(6, 0), #(chess.Knight, chess.White)),
      #(#(7, 0), #(chess.Rook, chess.White)),
      #(#(0, 1), #(chess.Pawn, chess.White)),
      #(#(1, 1), #(chess.Pawn, chess.White)),
      #(#(2, 1), #(chess.Pawn, chess.White)),
      #(#(3, 1), #(chess.Pawn, chess.White)),
      #(#(4, 1), #(chess.Pawn, chess.White)),
      #(#(5, 1), #(chess.Pawn, chess.White)),
      #(#(6, 1), #(chess.Pawn, chess.White)),
      #(#(7, 1), #(chess.Pawn, chess.White)),
      #(#(0, 7), #(chess.Rook, chess.Black)),
      #(#(1, 7), #(chess.Knight, chess.Black)),
      #(#(2, 7), #(chess.Bishop, chess.Black)),
      #(#(3, 7), #(chess.Queen, chess.Black)),
      #(#(4, 7), #(chess.King, chess.Black)),
      #(#(5, 7), #(chess.Bishop, chess.Black)),
      #(#(6, 7), #(chess.Knight, chess.Black)),
      #(#(7, 7), #(chess.Rook, chess.Black)),
      #(#(0, 6), #(chess.Pawn, chess.Black)),
      #(#(1, 6), #(chess.Pawn, chess.Black)),
      #(#(2, 6), #(chess.Pawn, chess.Black)),
      #(#(3, 6), #(chess.Pawn, chess.Black)),
      #(#(4, 6), #(chess.Pawn, chess.Black)),
      #(#(5, 6), #(chess.Pawn, chess.Black)),
      #(#(6, 6), #(chess.Pawn, chess.Black)),
      #(#(7, 6), #(chess.Pawn, chess.Black)),
    ]
    |> dict.from_list

  cells |> should.equal(expected_cells)
}

pub fn fen_to_game_e4_test() {
  let Game(Board(cells)) =
    fen_to_game("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")

  let expected_cells =
    [
      #(#(0, 0), #(chess.Rook, chess.White)),
      #(#(1, 0), #(chess.Knight, chess.White)),
      #(#(2, 0), #(chess.Bishop, chess.White)),
      #(#(3, 0), #(chess.Queen, chess.White)),
      #(#(4, 0), #(chess.King, chess.White)),
      #(#(5, 0), #(chess.Bishop, chess.White)),
      #(#(6, 0), #(chess.Knight, chess.White)),
      #(#(7, 0), #(chess.Rook, chess.White)),
      #(#(0, 1), #(chess.Pawn, chess.White)),
      #(#(1, 1), #(chess.Pawn, chess.White)),
      #(#(2, 1), #(chess.Pawn, chess.White)),
      #(#(3, 1), #(chess.Pawn, chess.White)),
      #(#(4, 3), #(chess.Pawn, chess.White)),
      #(#(5, 1), #(chess.Pawn, chess.White)),
      #(#(6, 1), #(chess.Pawn, chess.White)),
      #(#(7, 1), #(chess.Pawn, chess.White)),
      #(#(0, 7), #(chess.Rook, chess.Black)),
      #(#(1, 7), #(chess.Knight, chess.Black)),
      #(#(2, 7), #(chess.Bishop, chess.Black)),
      #(#(3, 7), #(chess.Queen, chess.Black)),
      #(#(4, 7), #(chess.King, chess.Black)),
      #(#(5, 7), #(chess.Bishop, chess.Black)),
      #(#(6, 7), #(chess.Knight, chess.Black)),
      #(#(7, 7), #(chess.Rook, chess.Black)),
      #(#(0, 6), #(chess.Pawn, chess.Black)),
      #(#(1, 6), #(chess.Pawn, chess.Black)),
      #(#(2, 6), #(chess.Pawn, chess.Black)),
      #(#(3, 6), #(chess.Pawn, chess.Black)),
      #(#(4, 6), #(chess.Pawn, chess.Black)),
      #(#(5, 6), #(chess.Pawn, chess.Black)),
      #(#(6, 6), #(chess.Pawn, chess.Black)),
      #(#(7, 6), #(chess.Pawn, chess.Black)),
    ]
    |> dict.from_list

  cells |> should.equal(expected_cells)
}
