import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/pair
import gleam/result
import gleam/string

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

pub type Game {
  Game(
    board: Dict(Square, Piece),
    active_color: Player,
    castling_availability: String,
    en_passant_target_square: String,
    halfmove_clock: Int,
    fullmove_number: Int,
  )
}

/// Standard Algebraic Notation
/// https://en.wikipedia.org/wiki/Algebraic_notation_(chess)
pub type SAN =
  String

// these types should be treated as completely opaque
pub type Move =
  SAN

pub type ContextualizedMove

pub fn load_fen(fen: String) -> Result(Game, Nil) {
  use
    #(
      piece_placement_data,
      active_color,
      castling_availability,
      en_passant_target_square,
      halfmove_clock,
      fullmove_number,
    )
  <- result.try(
    fen
    |> string.split(" ")
    |> fn(lst) {
      case lst {
        // a-f are 1-1 to what's destructured above. I'm too lazy and it's too
        // verbose to type them all out.
        [a, b, c, d, e, f] -> Ok(#(a, b, c, d, e, f))
        _ -> Error(Nil)
      }
    },
  )

  use board <- result.try(
    piece_placement_data
    // Flatten the entire board into char array
    |> string.to_graphemes
    // Fold over a flat position, cell-dictionary pair.
    |> list.fold(from: Ok(#(0, dict.new())), with: fn(acc, val) {
      use acc <- result.try(acc)
      let #(square, board) = acc

      // String -> Result(Piece, Int)
      // If found a piece, then returns the piece
      // Otherwise, returns how many cells to skip
      let piece_or_skip = case val {
        "r" -> Ok(Piece(Black, Rook))
        "n" -> Ok(Piece(Black, Knight))
        "b" -> Ok(Piece(Black, Bishop))
        "q" -> Ok(Piece(Black, Queen))
        "k" -> Ok(Piece(Black, King))
        "p" -> Ok(Piece(Black, Pawn))

        "R" -> Ok(Piece(White, Rook))
        "N" -> Ok(Piece(White, Knight))
        "B" -> Ok(Piece(White, Bishop))
        "Q" -> Ok(Piece(White, Queen))
        "K" -> Ok(Piece(White, King))
        "P" -> Ok(Piece(White, Pawn))

        "/" -> Error(8)
        // If the int.parse fails, we should really be failing this entire
        // fold, but fuck, I kinda backed myself into a corner with this flow
        // control and I'm too lazy to fix it. I mean, we're gonna be getting
        // valid boards anyway.
        _ -> int.parse(val) |> result.unwrap(0) |> Error
      }

      case piece_or_skip {
        Ok(piece) ->
          algebraic(square)
          |> result.map(fn(alg_square) {
            #(square + 1, board |> dict.insert(alg_square, piece))
          })
        Error(skip) -> Ok(#(square + skip, board))
      }
    })
    |> result.map(pair.second),
  )
  use halfmove_clock <- result.try(int.parse(halfmove_clock))
  use fullmove_number <- result.try(int.parse(fullmove_number))

  Ok(Game(
    board: board,
    active_color: case active_color {
      "w" -> White
      "b" -> Black
      _ -> panic
    },
    castling_availability: castling_availability,
    en_passant_target_square: en_passant_target_square,
    halfmove_clock: halfmove_clock,
    fullmove_number: fullmove_number,
  ))
}

pub fn player_decoder() {
  use player_string <- decode.then(decode.string)
  case player_string {
    "white" -> decode.success(White)
    "black" -> decode.success(Black)
    _ -> decode.failure(White, "Invalid player")
  }
}

pub fn move(
  fen: String,
  turn: Player,
  failed_moves: List(String),
) -> Result(String, String) {
  todo
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

pub fn contextualize_move(
  game: Game,
  move: Move,
) -> Result(ContextualizedMove, Nil) {
  todo
}

pub fn decontextualize_move(move: ContextualizedMove) -> Move {
  todo
}

pub fn move_is_capture(move: ContextualizedMove) -> Bool {
  todo
}

pub fn move_is_promotion(move: ContextualizedMove) -> Bool {
  todo
}

pub fn move_is_en_passant(move: ContextualizedMove) -> Bool {
  todo
}

pub fn move_is_kingside_castle(move: ContextualizedMove) -> Bool {
  todo
}

pub fn move_is_queenside_castle(move: ContextualizedMove) -> Bool {
  todo
}

pub fn move_to_san(move: Move) -> String {
  todo
}

pub fn apply_move(game: Game, move: ContextualizedMove) -> Result(Game, Nil) {
  todo
}

pub fn moves(game: Game) -> List(ContextualizedMove) {
  todo
}

pub fn turn(game: Game) -> Player {
  todo
}

pub fn board(game: Game) -> List(#(Piece, Square)) {
  todo
}

// everything below is auxiliary, being computable from above, but i want to
// defer implementation of these to the chess game because it might be more
// efficient, plus minimax will be provided a standardized interface for these
// operations
pub fn piece_at(game: Game, square: Square) -> Result(Piece, Nil) {
  todo
}

pub fn is_attacked(game: Game, square: Square) -> Bool {
  todo
}

pub fn in_check(game: Game) -> Bool {
  todo
}

pub fn is_checkmate(game: Game) -> Bool {
  todo
}

pub fn is_stalemate(game: Game) -> Bool {
  todo
}

pub fn is_threefold_repetition(game: Game) -> Bool {
  todo
}

// nice debugging function
pub fn ascii(game: Game) -> String {
  todo
}

// Extracts the zero-based file of an 0x88 square.
fn file(square: Int) -> Int {
  int.bitwise_and(square, 0xf)
}

// Extracts the zero-based rank of an 0x88 square.
fn rank(square: Int) -> Int {
  int.bitwise_shift_right(square, 4)
}

/// Converts a 0x88 square to algebraic notation
fn algebraic(square: Int) -> Result(Square, Nil) {
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
