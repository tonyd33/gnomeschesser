import gleam/int
import gleam/string
import util/result_addons

/// This manual formatting gets ruined by the formatter and I don't think
/// there's any option to suppress formatting for a line range :(
/// I keep a copy here in the comments so it's still readable.
/// pub type Square {
///   A8 B8 C8 D8 E8 F8 G8 H8
///   A7 B7 C7 D7 E7 F7 G7 H7
///   A6 B6 C6 D6 E6 F6 G6 H6
///   A5 B5 C5 D5 E5 F5 G5 H5
///   A4 B4 C4 D4 E4 F4 G4 H4
///   A3 B3 C3 D3 E3 F3 G3 H3
///   A2 B2 C2 D2 E2 F2 G2 H2
///   A1 B1 C1 D1 E1 F1 G1 H1
/// }
///
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
///
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

/// Extracts the zero-based file of an 0x88 square.
///
pub fn file(square: Int) -> Int {
  int.bitwise_and(square, 0xf)
}

/// Extracts the zero-based rank of an 0x88 square.
///
pub fn rank(square: Int) -> Int {
  int.bitwise_shift_right(square, 4)
}

/// Converts a 0x88 square to algebraic notation
///
pub fn algebraic(square: Int) -> Result(Square, Nil) {
  let f = file(square)
  let r = rank(square)

  case f, r {
    0, 0 -> Ok(A8)
    0, 1 -> Ok(A7)
    0, 2 -> Ok(A6)
    0, 3 -> Ok(A5)
    0, 4 -> Ok(A4)
    0, 5 -> Ok(A3)
    0, 6 -> Ok(A2)
    0, 7 -> Ok(A1)

    1, 0 -> Ok(B8)
    1, 1 -> Ok(B7)
    1, 2 -> Ok(B6)
    1, 3 -> Ok(B5)
    1, 4 -> Ok(B4)
    1, 5 -> Ok(B3)
    1, 6 -> Ok(B2)
    1, 7 -> Ok(B1)

    2, 0 -> Ok(C8)
    2, 1 -> Ok(C7)
    2, 2 -> Ok(C6)
    2, 3 -> Ok(C5)
    2, 4 -> Ok(C4)
    2, 5 -> Ok(C3)
    2, 6 -> Ok(C2)
    2, 7 -> Ok(C1)

    3, 0 -> Ok(D8)
    3, 1 -> Ok(D7)
    3, 2 -> Ok(D6)
    3, 3 -> Ok(D5)
    3, 4 -> Ok(D4)
    3, 5 -> Ok(D3)
    3, 6 -> Ok(D2)
    3, 7 -> Ok(D1)

    4, 0 -> Ok(E8)
    4, 1 -> Ok(E7)
    4, 2 -> Ok(E6)
    4, 3 -> Ok(E5)
    4, 4 -> Ok(E4)
    4, 5 -> Ok(E3)
    4, 6 -> Ok(E2)
    4, 7 -> Ok(E1)

    5, 0 -> Ok(F8)
    5, 1 -> Ok(F7)
    5, 2 -> Ok(F6)
    5, 3 -> Ok(F5)
    5, 4 -> Ok(F4)
    5, 5 -> Ok(F3)
    5, 6 -> Ok(F2)
    5, 7 -> Ok(F1)

    6, 0 -> Ok(G8)
    6, 1 -> Ok(G7)
    6, 2 -> Ok(G6)
    6, 3 -> Ok(G5)
    6, 4 -> Ok(G4)
    6, 5 -> Ok(G3)
    6, 6 -> Ok(G2)
    6, 7 -> Ok(G1)

    7, 0 -> Ok(H8)
    7, 1 -> Ok(H7)
    7, 2 -> Ok(H6)
    7, 3 -> Ok(H5)
    7, 4 -> Ok(H4)
    7, 5 -> Ok(H3)
    7, 6 -> Ok(H2)
    7, 7 -> Ok(H1)

    _, _ -> Error(Nil)
  }
}

pub fn string(square: Square) {
  case square {
    A8 -> "a8"
    B8 -> "b8"
    C8 -> "c8"
    D8 -> "d8"
    E8 -> "e8"
    F8 -> "f8"
    G8 -> "g8"
    H8 -> "h8"
    A7 -> "a7"
    B7 -> "b7"
    C7 -> "c7"
    D7 -> "d7"
    E7 -> "e7"
    F7 -> "f7"
    G7 -> "g7"
    H7 -> "h7"
    A6 -> "a6"
    B6 -> "b6"
    C6 -> "c6"
    D6 -> "d6"
    E6 -> "e6"
    F6 -> "f6"
    G6 -> "g6"
    H6 -> "h6"
    A5 -> "a5"
    B5 -> "b5"
    C5 -> "c5"
    D5 -> "d5"
    E5 -> "e5"
    F5 -> "f5"
    G5 -> "g5"
    H5 -> "h5"
    A4 -> "a4"
    B4 -> "b4"
    C4 -> "c4"
    D4 -> "d4"
    E4 -> "e4"
    F4 -> "f4"
    G4 -> "g4"
    H4 -> "h4"
    A3 -> "a3"
    B3 -> "b3"
    C3 -> "c3"
    D3 -> "d3"
    E3 -> "e3"
    F3 -> "f3"
    G3 -> "g3"
    H3 -> "h3"
    A2 -> "a2"
    B2 -> "b2"
    C2 -> "c2"
    D2 -> "d2"
    E2 -> "e2"
    F2 -> "f2"
    G2 -> "g2"
    H2 -> "h2"
    A1 -> "a1"
    B1 -> "b1"
    C1 -> "c1"
    D1 -> "d1"
    E1 -> "e1"
    F1 -> "f1"
    G1 -> "g1"
    H1 -> "h1"
  }
}

pub fn string_rank(square: Square) {
  square
  |> string
  |> string.last
  |> result_addons.expect_unsafe_panic
}

pub fn string_file(square: Square) {
  square
  |> string
  |> string.first
  |> result_addons.expect_unsafe_panic
}

pub fn from_string(square: String) -> Result(Square, Nil) {
  case square |> string.lowercase {
    "a8" -> Ok(A8)
    "b8" -> Ok(B8)
    "c8" -> Ok(C8)
    "d8" -> Ok(D8)
    "e8" -> Ok(E8)
    "f8" -> Ok(F8)
    "g8" -> Ok(G8)
    "h8" -> Ok(H8)
    "a7" -> Ok(A7)
    "b7" -> Ok(B7)
    "c7" -> Ok(C7)
    "d7" -> Ok(D7)
    "e7" -> Ok(E7)
    "f7" -> Ok(F7)
    "g7" -> Ok(G7)
    "h7" -> Ok(H7)
    "a6" -> Ok(A6)
    "b6" -> Ok(B6)
    "c6" -> Ok(C6)
    "d6" -> Ok(D6)
    "e6" -> Ok(E6)
    "f6" -> Ok(F6)
    "g6" -> Ok(G6)
    "h6" -> Ok(H6)
    "a5" -> Ok(A5)
    "b5" -> Ok(B5)
    "c5" -> Ok(C5)
    "d5" -> Ok(D5)
    "e5" -> Ok(E5)
    "f5" -> Ok(F5)
    "g5" -> Ok(G5)
    "h5" -> Ok(H5)
    "a4" -> Ok(A4)
    "b4" -> Ok(B4)
    "c4" -> Ok(C4)
    "d4" -> Ok(D4)
    "e4" -> Ok(E4)
    "f4" -> Ok(F4)
    "g4" -> Ok(G4)
    "h4" -> Ok(H4)
    "a3" -> Ok(A3)
    "b3" -> Ok(B3)
    "c3" -> Ok(C3)
    "d3" -> Ok(D3)
    "e3" -> Ok(E3)
    "f3" -> Ok(F3)
    "g3" -> Ok(G3)
    "h3" -> Ok(H3)
    "a2" -> Ok(A2)
    "b2" -> Ok(B2)
    "c2" -> Ok(C2)
    "d2" -> Ok(D2)
    "e2" -> Ok(E2)
    "f2" -> Ok(F2)
    "g2" -> Ok(G2)
    "h2" -> Ok(H2)
    "a1" -> Ok(A1)
    "b1" -> Ok(B1)
    "c1" -> Ok(C1)
    "d1" -> Ok(D1)
    "e1" -> Ok(E1)
    "f1" -> Ok(F1)
    "g1" -> Ok(G1)
    "h1" -> Ok(H1)
    _ -> Error(Nil)
  }
}

pub fn to_string(square: Square) -> Result(String, Nil) {
  case square {
    A8 -> Ok("a8")
    B8 -> Ok("b8")
    C8 -> Ok("c8")
    D8 -> Ok("d8")
    E8 -> Ok("e8")
    F8 -> Ok("f8")
    G8 -> Ok("g8")
    H8 -> Ok("h8")
    A7 -> Ok("a7")
    B7 -> Ok("b7")
    C7 -> Ok("c7")
    D7 -> Ok("d7")
    E7 -> Ok("e7")
    F7 -> Ok("f7")
    G7 -> Ok("g7")
    H7 -> Ok("h7")
    A6 -> Ok("a6")
    B6 -> Ok("b6")
    C6 -> Ok("c6")
    D6 -> Ok("d6")
    E6 -> Ok("e6")
    F6 -> Ok("f6")
    G6 -> Ok("g6")
    H6 -> Ok("h6")
    A5 -> Ok("a5")
    B5 -> Ok("b5")
    C5 -> Ok("c5")
    D5 -> Ok("d5")
    E5 -> Ok("e5")
    F5 -> Ok("f5")
    G5 -> Ok("g5")
    H5 -> Ok("h5")
    A4 -> Ok("a4")
    B4 -> Ok("b4")
    C4 -> Ok("c4")
    D4 -> Ok("d4")
    E4 -> Ok("e4")
    F4 -> Ok("f4")
    G4 -> Ok("g4")
    H4 -> Ok("h4")
    A3 -> Ok("a3")
    B3 -> Ok("b3")
    C3 -> Ok("c3")
    D3 -> Ok("d3")
    E3 -> Ok("e3")
    F3 -> Ok("f3")
    G3 -> Ok("g3")
    H3 -> Ok("h3")
    A2 -> Ok("a2")
    B2 -> Ok("b2")
    C2 -> Ok("c2")
    D2 -> Ok("d2")
    E2 -> Ok("e2")
    F2 -> Ok("f2")
    G2 -> Ok("g2")
    H2 -> Ok("h2")
    A1 -> Ok("a1")
    B1 -> Ok("b1")
    C1 -> Ok("c1")
    D1 -> Ok("d1")
    E1 -> Ok("e1")
    F1 -> Ok("f1")
    G1 -> Ok("g1")
    H1 -> Ok("h1")
    _ -> Error(Nil)
  }
}
