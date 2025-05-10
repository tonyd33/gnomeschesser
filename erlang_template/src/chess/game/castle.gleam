import chess/bitboard
import chess/player
import chess/square
import gleam/int
import gleam/list

pub type Castle {
  KingSide
  QueenSide
}

pub const kingside_file = 6

pub const queenside_file = 1

pub fn occupancy_squares(player: player.Player, castle: Castle) {
  let rank = square.player_rank(player)
  let files = case castle {
    KingSide -> [5, 6]
    QueenSide -> [1, 2, 3]
  }
  files
  |> list.map(fn(file) {
    let assert Ok(square) = square.from_rank_file(rank, file)
    square
  })
}

/// not including the king itself
pub fn unattacked_squares(player: player.Player, castle: Castle) {
  let rank = square.player_rank(player)
  let files = case castle {
    KingSide -> [5, 6]
    QueenSide -> [2, 3]
  }
  files
  |> list.map(fn(file) {
    let assert Ok(square) = square.from_rank_file(rank, file)
    square
  })
}

pub fn rook_from_file(castle: Castle) {
  case castle {
    KingSide -> 7
    QueenSide -> 0
  }
}

pub fn rook_start_position(side: player.Player, castle: Castle) {
  let assert Ok(square) =
    case side, castle {
      player.White, KingSide -> 0x07
      player.White, QueenSide -> 0x00
      player.Black, KingSide -> 0x77
      player.Black, QueenSide -> 0x70
    }
    |> square.from_ox88
  square
}
