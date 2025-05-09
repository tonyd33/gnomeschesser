import chess/game/castle
import chess/move
import chess/player
import gleam/list
import gleeunit/should

pub fn castle_king_move_test() {
  [
    castle.king_move(player.White, castle.KingSide),
    castle.king_move(player.White, castle.QueenSide),
    castle.king_move(player.Black, castle.KingSide),
    castle.king_move(player.Black, castle.QueenSide),
  ]
  |> list.map(move.to_lan)
  |> should.equal(["e1g1", "e1c1", "e8g8", "e8c8"])
}

pub fn castle_bitboards_test() {
  should.equal(
    castle.occupancy_bitboard(player.Black, castle.KingSide),
    0b_01100000_00000000_00000000_00000000_00000000_00000000_00000000_00000000,
  )
  should.equal(
    castle.occupancy_bitboard(player.Black, castle.QueenSide),
    0b_00001110_00000000_00000000_00000000_00000000_00000000_00000000_00000000,
  )
  should.equal(
    castle.occupancy_bitboard(player.White, castle.KingSide),
    0b_00000000_00000000_00000000_00000000_00000000_00000000_00000000_01100000,
  )
  should.equal(
    castle.occupancy_bitboard(player.White, castle.QueenSide),
    0b_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00001110,
  )
  should.equal(
    castle.unattacked_bitboard(player.Black, castle.KingSide),
    0b_01110000_00000000_00000000_00000000_00000000_00000000_00000000_00000000,
  )
  should.equal(
    castle.unattacked_bitboard(player.Black, castle.QueenSide),
    0b_00011100_00000000_00000000_00000000_00000000_00000000_00000000_00000000,
  )
  should.equal(
    castle.unattacked_bitboard(player.White, castle.KingSide),
    0b_00000000_00000000_00000000_00000000_00000000_00000000_00000000_01110000,
  )
  should.equal(
    castle.unattacked_bitboard(player.White, castle.QueenSide),
    0b_00000000_00000000_00000000_00000000_00000000_00000000_00000000_00011100,
  )
}
