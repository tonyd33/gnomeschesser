import gleam/dict.{type Dict}
import gleam/int

pub type Player {
  White
  Black
}

pub type PieceSymbol {
  Pawn
  Knight
  Bishop
  Rook
  Queen
  King
}

pub type Piece {
  Piece(player: Player, symbol: PieceSymbol)
}

pub type Castle {
  KingSide
  QueenSide
}

// This manual formatting gets ruined by the formatter and I don't think
// there's any option to suppress formatting for a line range :(
// I keep a copy here in the comments so it's still readable.
// pub type Square {
//   A8 B8 C8 D8 E8 F8 G8 H8
//   A7 B7 C7 D7 E7 F7 G7 H7
//   A6 B6 C6 D6 E6 F6 G6 H6
//   A5 B5 C5 D5 E5 F5 G5 H5
//   A4 B4 C4 D4 E4 F4 G4 H4
//   A3 B3 C3 D3 E3 F3 G3 H3
//   A2 B2 C2 D2 E2 F2 G2 H2
//   A1 B1 C1 D1 E1 F1 G1 H1
// }
pub type Square {
  A8
  B8
  C8
  D8
  E8
  F8
  G8
  H8
  A7
  B7
  C7
  D7
  E7
  F7
  G7
  H7
  A6
  B6
  C6
  D6
  E6
  F6
  G6
  H6
  A5
  B5
  C5
  D5
  E5
  F5
  G5
  H5
  A4
  B4
  C4
  D4
  E4
  F4
  G4
  H4
  A3
  B3
  C3
  D3
  E3
  F3
  G3
  H3
  A2
  B2
  C2
  D2
  E2
  F2
  G2
  H2
  A1
  B1
  C1
  D1
  E1
  F1
  G1
  H1
}

/// See chess.js reference:
/// https://github.com/jhlywa/chess.js/blob/d68055f4dae7c06d100f21d385906743dce47abc/src/chess.ts#L205
pub fn ox88(square: Square) -> Int {
  case square {
    A8 -> 0
    B8 -> 1
    C8 -> 2
    D8 -> 3
    E8 -> 4
    F8 -> 5
    G8 -> 6
    H8 -> 7
    A7 -> 16
    B7 -> 17
    C7 -> 18
    D7 -> 19
    E7 -> 20
    F7 -> 21
    G7 -> 22
    H7 -> 23
    A6 -> 32
    B6 -> 33
    C6 -> 34
    D6 -> 35
    E6 -> 36
    F6 -> 37
    G6 -> 38
    H6 -> 39
    A5 -> 48
    B5 -> 49
    C5 -> 50
    D5 -> 51
    E5 -> 52
    F5 -> 53
    G5 -> 54
    H5 -> 55
    A4 -> 64
    B4 -> 65
    C4 -> 66
    D4 -> 67
    E4 -> 68
    F4 -> 69
    G4 -> 70
    H4 -> 71
    A3 -> 80
    B3 -> 81
    C3 -> 82
    D3 -> 83
    E3 -> 84
    F3 -> 85
    G3 -> 86
    H3 -> 87
    A2 -> 96
    B2 -> 97
    C2 -> 98
    D2 -> 99
    E2 -> 100
    F2 -> 101
    G2 -> 102
    H2 -> 103
    A1 -> 112
    B1 -> 113
    C1 -> 114
    D1 -> 115
    E1 -> 116
    F1 -> 117
    G1 -> 118
    H1 -> 119
  }
}

pub const squares: List(Square) = [
  A8,
  B8,
  C8,
  D8,
  E8,
  F8,
  G8,
  H8,
  A7,
  B7,
  C7,
  D7,
  E7,
  F7,
  G7,
  H7,
  A6,
  B6,
  C6,
  D6,
  E6,
  F6,
  G6,
  H6,
  A5,
  B5,
  C5,
  D5,
  E5,
  F5,
  G5,
  H5,
  A4,
  B4,
  C4,
  D4,
  E4,
  F4,
  G4,
  H4,
  A3,
  B3,
  C3,
  D3,
  E3,
  F3,
  G3,
  H3,
  A2,
  B2,
  C2,
  D2,
  E2,
  F2,
  G2,
  H2,
  A1,
  B1,
  C1,
  D1,
  E1,
  F1,
  G1,
  H1,
]

pub type Game {
  Game(
    board: Dict(Square, Piece),
    active_color: Player,
    // TODO: Change to List(#(Player, Castle))
    castling_availability: String,
    // TODO: Change into Square
    en_passant_target_square: String,
    halfmove_clock: Int,
    fullmove_number: Int,
    // TODO: Possibly don't need this
    moves: List(Move),
  )
}

/// Standard Algebraic Notation
/// https://en.wikipedia.org/wiki/Algebraic_notation_(chess)
pub type SAN =
  String

pub type Move =
  SAN
