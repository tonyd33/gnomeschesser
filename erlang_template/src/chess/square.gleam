import chess/piece
import chess/player
import gleam/bool
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import util/direction

pub const king_file = 4

///   A8 B8 C8 D8 E8 F8 G8 H8
///   A7 B7 C7 D7 E7 F7 G7 H7
///   A6 B6 C6 D6 E6 F6 G6 H6
///   A5 B5 C5 D5 E5 F5 G5 H5
///   A4 B4 C4 D4 E4 F4 G4 H4
///   A3 B3 C3 D3 E3 F3 G3 H3
///   A2 B2 C2 D2 E2 F2 G2 H2
///   A1 B1 C1 D1 E1 F1 G1 H1
///
/// https://en.wikipedia.org/wiki/0x88
///
pub opaque type Square {
  Square(ox88: Int)
}

/// See chess.js reference:
/// https://github.com/jhlywa/chess.js/blob/d68055f4dae7c06d100f21d385906743dce47abc/src/chess.ts#L205
/// https://en.wikipedia.org/wiki/0x88
///
pub fn to_ox88(square: Square) -> Int {
  square.ox88
}

pub fn get_squares() -> List(Square) {
  [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]
  |> list.flat_map(fn(rank) {
    [0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0x00]
    |> list.map(int.bitwise_or(_, rank))
  })
  |> list.map(Square)
}

/// Extracts the file of a square from 0 to 7
///
pub fn file(square: Square) -> Int {
  int.bitwise_and(square.ox88, 0x0f)
}

/// Extracts the rank of a square from 0 to 7
///
pub fn rank(square: Square) -> Int {
  // Extract the 0x_0 bit
  int.bitwise_shift_right(square.ox88, 4)
}

pub fn rank_to_string(rank: Int) -> String {
  int.to_string(rank + 1)
}

pub fn file_to_string(file: Int) -> String {
  // we can probably just use a case statement here at some point
  let assert [a] = string.to_utf_codepoints("a")
  let assert Ok(file_utf) =
    string.utf_codepoint(string.utf_codepoint_to_int(a) + file)
  string.from_utf_codepoints([file_utf])
}

pub fn to_string(square: Square) -> String {
  file_to_string(file(square)) <> rank_to_string(rank(square))
}

pub fn file_from_string(file: String) -> Result(Int, Nil) {
  let utf_codepoints = string.to_utf_codepoints(string.lowercase(file))
  use <- bool.guard(list.length(utf_codepoints) != 1, Error(Nil))
  let assert [a_utf] = string.to_utf_codepoints("a")
  let assert [file_utf] = utf_codepoints
  Ok(string.utf_codepoint_to_int(file_utf) - string.utf_codepoint_to_int(a_utf))
}

pub fn rank_from_string(rank: String) -> Result(Int, Nil) {
  use <- bool.guard(string.length(rank) != 1, Error(Nil))
  result.map(int.parse(rank), int.subtract(_, 1))
}

pub fn from_string(square: String) -> Result(Square, Nil) {
  let graphemes = string.to_graphemes(string.lowercase(square))
  use <- bool.guard(list.length(graphemes) != 2, Error(Nil))
  let assert [file_string, rank_string] = graphemes
  let file = file_from_string(file_string)
  let rank = rank_from_string(rank_string)
  case rank, file {
    Ok(rank), Ok(file) -> from_rank_file(rank, file)
    _, _ -> Error(Nil)
  }
}

/// Where rank and file are from 0 to 7
///
pub fn from_rank_file(rank: Int, file: Int) -> Result(Square, Nil) {
  case file >= 0 && file < 8 && rank >= 0 && rank < 8 {
    True -> Ok(Square(int.bitwise_or(int.bitwise_shift_left(rank, 4), file)))
    False -> Error(Nil)
  }
}

pub fn from_ox88(ox88: Int) -> Result(Square, Nil) {
  case is_valid(ox88) {
    True -> Ok(Square(ox88:))
    False -> Error(Nil)
  }
}

pub fn move(
  square: Square,
  direction: direction.Direction,
  distance: Int,
) -> Result(Square, Nil) {
  case direction {
    direction.Up -> 16
    direction.Down -> -16
    direction.Left -> -1
    direction.Right -> 1
  }
  * int.clamp(distance, -8, 8)
  + square.ox88
  |> from_ox88
}

pub fn add(square: Square, increment: Int) -> Result(Square, Nil) {
  let ox88 = square.ox88 + increment
  from_ox88(ox88)
}

fn is_valid(ox88: Int) -> Bool {
  0 == int.bitwise_and(ox88, int.bitwise_not(0x77))
}

pub fn pawn_start_rank(player: player.Player) -> Int {
  case player {
    player.White -> 1
    player.Black -> 6
  }
}

pub fn pawn_promotion_rank(player: player.Player) -> Int {
  case player {
    player.White -> 7
    player.Black -> 0
  }
}

pub fn player_rank(player: player.Player) -> Int {
  case player {
    player.White -> 0
    player.Black -> 7
  }
}

/// List of lists of squares being "paths" a piece can travel down
/// This does not consider any obstacles
pub fn piece_moves(from: Square, piece: piece.Piece) -> List(List(Square)) {
  let depths = case piece.symbol {
    piece.Knight | piece.King -> [1]
    piece.Bishop | piece.Queen | piece.Rook -> [1, 2, 3, 4, 5, 6, 7, 8]
    piece.Pawn -> panic as "We don't support using piece_moves for pawns"
  }

  piece_offsets(piece)
  |> list.map(fn(offset) {
    list.filter_map(depths, fn(depth) { from_ox88(offset * depth + from.ox88) })
  })
}

/// Gets the ox88 offsets of each piece's "one space" moves
fn piece_offsets(piece: piece.Piece) {
  case piece.symbol {
    piece.Knight -> [-18, -33, -31, -14, 18, 33, 31, 14]
    piece.Bishop -> [-17, -15, 17, 15]
    piece.King -> [-17, -16, -15, 1, 17, 16, 15, -1]
    piece.Pawn -> panic as "We don't support using piece_offsets for pawns"
    piece.Queen -> [-17, -16, -15, 1, 17, 16, 15, -1]
    piece.Rook -> [-16, 1, 16, -1]
  }
}
