import chess/bitboard
import chess/game
import chess/square
import gleeunit/should

pub fn from_square_test() {
  let assert Ok(square) = square.from_rank_file(1, 2)
  bitboard.from_square(square)
  |> should.equal(0b00000100_00000000)
}

// pub fn to_square_test() {
//   use rank <- list.each(list.range(0, 7))
//   use file <- list.each(list.range(0, 7))
//   let assert Ok(square) = square.from_rank_file(rank, file)
//   bitboard.from_square(square)
//   |> bitboard.to_squares
//   |> should.equal([square])
// }

// pub fn move_test() {
//   let assert Ok(square) = square.from_rank_file(4, 4)
//   let assert Ok(up_square) = square.from_rank_file(5, 4)
//   let assert Ok(down_square) = square.from_rank_file(3, 4)
//   let assert Ok(right_square) = square.from_rank_file(4, 5)
//   let assert Ok(left_square) = square.from_rank_file(4, 3)
//   let bitboard = bitboard.from_square(square)

//   bitboard
//   |> bitboard.move(direction.Up, 1)
//   |> bitboard.to_squares
//   |> should.equal([up_square])
//   bitboard
//   |> bitboard.move(direction.Down, 1)
//   |> bitboard.to_squares
//   |> should.equal([down_square])
//   bitboard
//   |> bitboard.move(direction.Left, 1)
//   |> bitboard.to_squares
//   |> should.equal([left_square])
//   bitboard
//   |> bitboard.move(direction.Right, 1)
//   |> bitboard.to_squares
//   |> should.equal([right_square])
// }

pub fn board_test() {
  let assert Ok(game) = game.load_fen(game.start_fen)
  game.get_game_bitboard(game)
  |> should.equal(bitboard.GameBitboard(
    white_pawns: 0b00_11111111_00000000,
    white_knights: 0b_00000000_01000010,
    white_bishops: 0b_00000000_00100100,
    white_rooks: 0b00_00000000_10000001,
    white_queens: 0b0_00000000_00001000,
    white_king: 0b000_00000000_00010000,
    black_pawns: 0b00_00000000_11111111_00000000_00000000_00000000_00000000_00000000_00000000,
    black_knights: 0b_01000010_00000000_00000000_00000000_00000000_00000000_00000000_00000000,
    black_bishops: 0b_00100100_00000000_00000000_00000000_00000000_00000000_00000000_00000000,
    black_rooks: 0b00_10000001_00000000_00000000_00000000_00000000_00000000_00000000_00000000,
    black_queens: 0b0_00001000_00000000_00000000_00000000_00000000_00000000_00000000_00000000,
    black_king: 0b000_00010000_00000000_00000000_00000000_00000000_00000000_00000000_00000000,
  ))
}
// pub fn move_off_board_test() {
//   0b10000000_10000000_10000000_10000000_10000000_10000000_10000000_10000000
//   |> bitboard.move(direction.Right, 1)
//   |> should.equal(0)
//   0b00000001_00000001_00000001_00000001_00000001_00000001_00000001_00000001
//   |> bitboard.move(direction.Left, 1)
//   |> should.equal(0)
//   0b00000000_00000000_00000000_00000000_00000000_00000000_00000000_11111111
//   |> bitboard.move(direction.Down, 1)
//   |> should.equal(0)
//   0b11111111_00000000_00000000_00000000_00000000_00000000_00000000_00000000
//   |> bitboard.move(direction.Up, 1)
//   |> should.equal(0)
// }
