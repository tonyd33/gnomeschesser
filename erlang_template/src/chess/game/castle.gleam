import chess/player
import chess/square
import gleam/list

pub type Castle {
  KingSide
  QueenSide
}

pub type CastlingAvailability {
  CastlingAvailability(
    white_kingside: Bool,
    white_queenside: Bool,
    black_kingside: Bool,
    black_queenside: Bool,
  )
}

pub const no_castling_availability = CastlingAvailability(
  white_kingside: False,
  white_queenside: False,
  black_kingside: False,
  black_queenside: False,
)

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

pub fn rook_from_position(side: player.Player, castle: Castle) {
  case side, castle {
    player.White, KingSide -> 0x07
    player.White, QueenSide -> 0x00
    player.Black, KingSide -> 0x77
    player.Black, QueenSide -> 0x70
  }
}

pub fn rook_to_position(side: player.Player, castle: Castle) {
  let rank = square.player_rank(side)
  let to_file = case castle {
    KingSide -> 5
    QueenSide -> 3
  }
  let assert Ok(to) = square.from_rank_file(rank, to_file)
  to
}
