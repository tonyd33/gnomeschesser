import chess/bitboard
import chess/player
import chess/square
import gleam/int

pub type Castle {
  KingSide
  QueenSide
}

pub const kingside_file = 6

pub const queenside_file = 1

pub fn occupancy_bitboard(
  player: player.Player,
  castle: Castle,
) -> bitboard.BitBoard {
  let row = case castle {
    KingSide -> 0b_0110_0000
    QueenSide -> 0b_0000_1110
  }
  let rank = square.player_rank(player)
  int.bitwise_shift_left(row, rank * 8)
}

pub fn unattacked_bitboard(
  player: player.Player,
  castle: Castle,
) -> bitboard.BitBoard {
  let row = case castle {
    KingSide -> 0b01110000
    QueenSide -> 0b00011100
  }
  let rank = square.player_rank(player)
  int.bitwise_shift_left(row, rank * 8)
}

pub fn rook_from_file(castle: Castle) {
  case castle {
    KingSide -> 7
    QueenSide -> 0
  }
}

/// Bitboard of each rook's initial position to be castleable
pub fn rook_initial_bitboard(player: player.Player, side: Castle) {
  case player, side {
    player.White, KingSide -> 0b0_10000000
    player.White, QueenSide -> 0b_00000001
    player.Black, KingSide ->
      0b_10000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000
    player.Black, QueenSide ->
      0b_00000001_00000000_00000000_00000000_00000000_00000000_00000000_00000000
  }
}

pub fn king_initial_bitboard(player: player.Player) {
  case player {
    player.White -> 0b_00010000
    player.Black ->
      0b_00010000_00000000_00000000_00000000_00000000_00000000_00000000_00000000
  }
}
