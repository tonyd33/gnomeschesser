import chess/bitboard
import chess/move
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

pub fn rook_move(
  player: player.Player,
  castle: Castle,
) -> move.Move(move.Pseudo) {
  let rank = square.player_rank(player)
  let from_file = rook_from_file(castle)
  let to_file = case castle {
    KingSide -> 5
    QueenSide -> 3
  }
  let assert Ok(from) = square.from_rank_file(rank, from_file)
  let assert Ok(to) = square.from_rank_file(rank, to_file)
  move.new_pseudomove(from:, to:)
}

pub fn king_move(
  player: player.Player,
  castle: Castle,
) -> move.Move(move.Pseudo) {
  let rank = square.player_rank(player)

  let to_file = case castle {
    KingSide -> 6
    QueenSide -> 2
  }

  let assert Ok(from) = square.from_rank_file(rank, square.king_file)
  let assert Ok(to) = square.from_rank_file(rank, to_file)
  move.new_pseudomove(from:, to:)
}
