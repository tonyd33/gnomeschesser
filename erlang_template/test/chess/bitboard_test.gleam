import chess/bitboard
import chess/square
import gleam/list
import gleeunit/should

pub fn from_square_test() {
  let assert Ok(square) = square.from_rank_file(1, 2)
  bitboard.from_square(square)
  |> should.equal(0b00100000_00000000)
}

pub fn to_square_test() {
  use rank <- list.each(list.range(0, 7))
  use file <- list.each(list.range(0, 7))
  let assert Ok(square) = square.from_rank_file(rank, file)
  bitboard.from_square(square)
  |> bitboard.to_squares
  |> should.equal([square])
}
