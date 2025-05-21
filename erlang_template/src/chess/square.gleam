import chess/constants_store.{type ConstantsStore}
import chess/piece
import chess/player
import gleam/bool
import gleam/dict
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/pair
import gleam/result
import gleam/string
import iv.{type Array}
import util/direction
import util/yielder

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
pub type Square =
  Int

pub type Square64 =
  Int

/// See chess.js reference:
/// https://github.com/jhlywa/chess.js/blob/d68055f4dae7c06d100f21d385906743dce47abc/src/chess.ts#L205
/// https://en.wikipedia.org/wiki/0x88
///
pub fn to_ox88(square: Square) -> Int {
  square
}

/// Get the 64-based representation of the square
///
pub fn to_64(square: Square) -> Square64 {
  let file = file(square)
  let rank = rank(square)
  { 8 * rank } + file
}

pub fn square64_to_ox88(square: Square64) -> Result(Square, Nil) {
  let #(rank, file) = #(square / 8, square % 8)
  from_rank_file(rank, file)
}

pub fn make_square64(x: Int) {
  x
}

pub fn get_squares() -> List(Square) {
  [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07]
  |> list.flat_map(fn(rank) {
    [0x70, 0x60, 0x50, 0x40, 0x30, 0x20, 0x10, 0x00]
    |> list.map(int.bitwise_or(_, rank))
  })
}

/// Extracts the file of a square from 0 to 7
///
pub fn file(square: Square) -> Int {
  int.bitwise_and(square, 0x0f)
}

/// Extracts the rank of a square from 0 to 7
///
pub fn rank(square: Square) -> Int {
  // Extract the 0x_0 bit
  int.bitwise_shift_right(square, 4)
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
    True -> Ok(int.bitwise_or(int.bitwise_shift_left(rank, 4), file))
    False -> Error(Nil)
  }
}

pub fn from_ox88(ox88: Int) -> Result(Square, Nil) {
  case is_valid(ox88) {
    True -> Ok(ox88)
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
  + square
  |> from_ox88
}

pub fn add(square: Square, increment: Int) -> Result(Square, Nil) {
  let ox88 = square + increment
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

/// returns the offset to slide from square1 to square2
/// 0 if not in a line
/// also returns the number of squares in between
pub fn ray_to_offset(from from: Square, to to: Square) {
  let difference = from - to
  let offset = rays(difference + 0x77)
  let steps = int.absolute_value(difference / offset)
  #(offset, steps)
}

/// Shoots a ray vertical/horizontal/diagonals
/// returns the first piece hit if it exists
/// otherwise returns error
pub fn piece_attacking_ray(
  occupancy: dict.Dict(Square, piece.Piece),
  from: Square,
  to: Square,
) -> Result(piece.Piece, Nil) {
  let difference = to - from
  use offset <- result.try({
    case difference {
      diff if diff % 16 == 0 -> int.clamp(diff, -16, 16) |> Ok
      diff if diff < 8 && diff > -8 -> int.clamp(diff, -1, 1) |> Ok
      diff if diff % 15 == 0 -> int.clamp(diff, -15, 15) |> Ok
      diff if diff % 17 == 0 -> int.clamp(diff, -17, 17) |> Ok
      _ -> Error(Nil)
    }
  })

  [1, 2, 3, 4, 5, 6, 7, 8]
  |> list.find_map(fn(depth) {
    use to <- result.try(from_ox88(offset * depth + from))
    dict.get(occupancy, to)
  })
}

/// considers squares that are attackable
/// returns a list of squares attacking until and
/// including the first piece hit if it's the opponent's
pub fn piece_attacking(
  occupancy: Array(Option(piece.Piece)),
  from: Square,
  piece: piece.Piece,
  opponent_only: Bool,
) -> List(Square) {
  let depths = case piece.symbol {
    piece.Knight | piece.King | piece.Pawn -> [1]
    piece.Bishop | piece.Queen | piece.Rook -> [1, 2, 3, 4, 5, 6, 7, 8]
  }

  let us = piece.player

  piece_attack_offsets(piece)
  |> list.flat_map(fn(offset) {
    list.fold_until(depths, [], fn(acc, depth) {
      case from_ox88(offset * depth + from) {
        Ok(to) ->
          case board_get(occupancy, to), opponent_only {
            Ok(piece.Piece(player, _)), True if player == us -> list.Stop(acc)
            Error(Nil), _ -> list.Continue([to, ..acc])
            _, _ -> list.Stop([to, ..acc])
          }
        Error(Nil) -> list.Stop(acc)
      }
    })
  })
}

pub fn get_squares_attacking_at(
  board: Array(Option(piece.Piece)),
  at: Square,
  by: player.Player,
) -> List(Square) {
  board
  |> iv.index_fold([], fn(acc, piece, from_64: Square64) {
    case piece {
      None -> acc
      Some(piece) -> {
        let from64 = from_64
        let assert Ok(from) = square64_to_ox88(from64)
        // We only consider attacks by a certain player
        use <- bool.guard(piece.player != by, acc)

        let difference = from - at
        // skip if to/from square are the same
        use <- bool.guard(difference == 0, acc)

        // This index is used for `attacks` and `rays`, where a difference of 0 corresponds to the centre
        let index = difference + 0x77

        // `attacks` lets us index which type of piece can attack from that square
        // if it's not the piece we currently have, we just return
        use <- bool.guard(
          int.bitwise_and(attacks(index), piece_masks(piece.symbol)) == 0,
          acc,
        )

        let x = case piece.symbol {
          // Knights and Kings can't be blocked
          piece.Knight | piece.King -> Ok(from)
          // Pawns can't be blocked
          piece.Pawn ->
            // Pawns can only attack forwards, so we check which side they're on
            case piece.player, int.compare(difference, 0) {
              player.Black, order.Gt | player.White, order.Lt -> Ok(from)
              _, _ -> Error(Nil)
            }
          // These slide, so we check if their path is empty
          piece.Bishop | piece.Queen | piece.Rook -> {
            let offset = rays(index)

            let first = from
            let last = at - offset
            let iterations = { last - first } / offset
            use <- bool.guard(iterations <= 0, Ok(from))
            let is_attacking =
              yielder.iterate(first + offset, int.add(_, offset))
              |> yielder.take(iterations)
              |> yielder.all(fn(ox88) {
                board_get(board, ox88) |> result.is_error
              })

            case is_attacking {
              True -> Ok(from)
              False -> Error(Nil)
            }
          }
        }
        case x {
          Ok(x) -> [x, ..acc]
          _ -> acc
        }
      }
    }
  })
}

pub fn is_attacked_at(
  board: Array(Option(piece.Piece)),
  at: Square,
  by: player.Player,
  store: ConstantsStore,
) -> Bool {
  store.range_64
  |> iv.any(fn(from_64) {
    let assert Ok(from) = square64_to_ox88(from_64)
    case board_get(board, from) {
      Ok(piece) -> {
        // We only consider attacks by a certain player
        use <- bool.guard(piece.player != by, False)

        let difference = from - at
        // skip if to/from square are the same
        use <- bool.guard(difference == 0, False)

        // This index is used for `attacks` and `rays`, where a difference of 0 corresponds to the centre
        let index = difference + 0x77

        // `attacks` lets us index which type of piece can attack from that square
        // if it's not the piece we currently have, we just return
        use <- bool.guard(
          int.bitwise_and(attacks(index), piece_masks(piece.symbol)) == 0,
          False,
        )

        case piece.symbol {
          // Knights and Kings can't be blocked
          piece.Knight | piece.King -> True
          // Pawns can't be blocked
          piece.Pawn ->
            // Pawns can only attack forwards, so we check which side they're on
            case piece.player, int.compare(difference, 0) {
              player.Black, order.Gt | player.White, order.Lt -> True
              _, _ -> False
            }
          // These slide, so we check if their path is empty
          piece.Bishop | piece.Queen | piece.Rook -> {
            let offset = rays(index)
            let first = from
            let last = at - offset
            let iterations = { last - first } / offset
            use <- bool.guard(iterations <= 0, True)
            yielder.iterate(first + offset, int.add(_, offset))
            |> yielder.take(iterations)
            |> yielder.all(fn(ox88) {
              board_get(board, ox88) |> result.is_error
            })
          }
        }
      }
      _ -> False
    }
  })
}

fn board_get(board: Array(Option(piece.Piece)), square: Square) {
  let d64 = to_64(square)
  case iv.get(board, d64) {
    Ok(Some(piece)) -> Ok(piece)
    _ -> Error(Nil)
  }
}

/// calculates all attacks (and pinned pieces from attacks) to a certain square
/// Does not handle en passant specialcase, that is specially checked later on
/// This is for determining if the king is in check
/// Returns a list of attackers as well as pinned piece if it exists
pub fn attacks_and_pins_to(
  board: Array(Option(piece.Piece)),
  at: Square,
  by: player.Player,
) -> List(#(Square, option.Option(Square))) {
  let _attacks_and_pins =
    board
    |> iv.index_fold([], fn(acc, piece, from_64) {
      case piece {
        Some(piece) -> {
          let assert Ok(from) = square64_to_ox88(from_64)
          // We only consider attacks by a certain player
          use <- bool.guard(piece.player != by, acc)

          let difference = from - at
          // skip if to/from square are the same
          use <- bool.guard(difference == 0, acc)

          // This index is used for `attacks` and `rays`, where a difference of 0 corresponds to the centre
          let index = difference + 0x77

          // `attacks` lets us index which type of piece can attack from that square
          // if it's not the piece we currently have, we just return
          use <- bool.guard(
            int.bitwise_and(attacks(index), piece_masks(piece.symbol)) == 0,
            acc,
          )

          let x = case piece.symbol {
            // Knights and Kings can't be blocked
            piece.Knight | piece.King -> Ok(#(from, option.None))
            // Pawns can't be blocked
            piece.Pawn ->
              // Pawns can only attack forwards, so we check which side they're on
              case piece.player, int.compare(difference, 0) {
                player.Black, order.Gt | player.White, order.Lt ->
                  Ok(#(from, option.None))
                _, _ -> Error(Nil)
              }
            // These slide, so we check if their path is empty
            piece.Bishop | piece.Queen | piece.Rook -> {
              let offset = rays(index)

              let first = from + offset
              let last = at - offset
              let iterations = { { last - first } / offset } + 1
              use <- bool.guard(iterations <= 0, Ok(#(from, option.None)))
              // We shoot two rays, one from from -> to, then to -> from, if the piece is the same and "ours"
              // Then that is a pinned piece
              let source_to_target_piece =
                yielder.iterate(first, int.add(_, offset))
                |> yielder.take(iterations)
                |> yielder.find_map(fn(ox88) {
                  board_get(board, ox88)
                  |> result.map(pair.new(ox88, _))
                })

              use <- bool.guard(
                source_to_target_piece |> result.is_error,
                Ok(#(from, option.None)),
              )
              case source_to_target_piece {
                Error(Nil) -> Ok(#(from, option.None))
                Ok(#(first_hit_square, piece)) -> {
                  use <- bool.guard(piece.player == by, Error(Nil))
                  // shoot the second ray
                  let target_to_source_piece =
                    yielder.iterate(last, int.subtract(_, offset))
                    |> yielder.take(iterations)
                    |> yielder.find(fn(ox88) {
                      board_get(board, ox88) |> result.is_ok
                    })
                  // if the first hit, then this must hit as well
                  let assert Ok(second_hit_square) = target_to_source_piece
                  use <- bool.guard(
                    second_hit_square != first_hit_square,
                    Error(Nil),
                  )
                  Ok(#(from, option.Some(first_hit_square)))
                }
              }
            }
          }
          case x {
            Ok(x) -> [x, ..acc]
            _ -> acc
          }
        }
        _ -> acc
      }
    })
}

// BEGIN: CONSTANTS

/// Gets the ox88 offsets of each piece's "one space" moves
/// Considers attacks only (so only x moves for pawns)
pub fn piece_attack_offsets(piece: piece.Piece) {
  case piece.symbol {
    piece.Knight -> [-18, -33, -31, -14, 18, 33, 31, 14]
    piece.Bishop -> [-17, -15, 17, 15]
    piece.King -> [-17, -16, -15, 1, 17, 16, 15, -1]
    piece.Pawn ->
      case piece.player {
        player.White -> [17, 15]
        player.Black -> [-17, -15]
      }
    piece.Queen -> [-17, -16, -15, 1, 17, 16, 15, -1]
    piece.Rook -> [-16, 1, 16, -1]
  }
}

fn piece_masks(piece: piece.PieceSymbol) {
  case piece {
    piece.Pawn -> 0x1
    piece.Knight -> 0x2
    piece.Bishop -> 0x4
    piece.Rook -> 0x8
    piece.Queen -> 0x10
    piece.King -> 0x20
  }
}

/// Returns the piece masks of the type of pieces that can
/// attack, given a difference of ox88 positions + 0x77
/// Note pawns are treated generally here
/// 20, 0, 0, 0, 0, 0, 0, 24,  0, 0, 0, 0, 0, 0,20, 0,
///  0,20, 0, 0, 0, 0, 0, 24,  0, 0, 0, 0, 0,20, 0, 0,
///  0, 0,20, 0, 0, 0, 0, 24,  0, 0, 0, 0,20, 0, 0, 0,
///  0, 0, 0,20, 0, 0, 0, 24,  0, 0, 0,20, 0, 0, 0, 0,
///  0, 0, 0, 0,20, 0, 0, 24,  0, 0,20, 0, 0, 0, 0, 0,
///  0, 0, 0, 0, 0,20, 2, 24,  2,20, 0, 0, 0, 0, 0, 0,
///  0, 0, 0, 0, 0, 2,53, 56, 53, 2, 0, 0, 0, 0, 0, 0,
/// 24,24,24,24,24,24,56,  0, 56,24,24,24,24,24,24, 0,
///  0, 0, 0, 0, 0, 2,53, 56, 53, 2, 0, 0, 0, 0, 0, 0,
///  0, 0, 0, 0, 0,20, 2, 24,  2,20, 0, 0, 0, 0, 0, 0,
///  0, 0, 0, 0,20, 0, 0, 24,  0, 0,20, 0, 0, 0, 0, 0,
///  0, 0, 0,20, 0, 0, 0, 24,  0, 0, 0,20, 0, 0, 0, 0,
///  0, 0,20, 0, 0, 0, 0, 24,  0, 0, 0, 0,20, 0, 0, 0,
///  0,20, 0, 0, 0, 0, 0, 24,  0, 0, 0, 0, 0,20, 0, 0,
/// 20, 0, 0, 0, 0, 0, 0, 24,  0, 0, 0, 0, 0, 0,20
fn attacks(difference: Int) {
  case difference {
    0 -> 20
    1 -> 0
    2 -> 0
    3 -> 0
    4 -> 0
    5 -> 0
    6 -> 0
    7 -> 24
    8 -> 0
    9 -> 0
    10 -> 0
    11 -> 0
    12 -> 0
    13 -> 0
    14 -> 20
    15 -> 0
    16 -> 0
    17 -> 20
    18 -> 0
    19 -> 0
    20 -> 0
    21 -> 0
    22 -> 0
    23 -> 24
    24 -> 0
    25 -> 0
    26 -> 0
    27 -> 0
    28 -> 0
    29 -> 20
    30 -> 0
    31 -> 0
    32 -> 0
    33 -> 0
    34 -> 20
    35 -> 0
    36 -> 0
    37 -> 0
    38 -> 0
    39 -> 24
    40 -> 0
    41 -> 0
    42 -> 0
    43 -> 0
    44 -> 20
    45 -> 0
    46 -> 0
    47 -> 0
    48 -> 0
    49 -> 0
    50 -> 0
    51 -> 20
    52 -> 0
    53 -> 0
    54 -> 0
    55 -> 24
    56 -> 0
    57 -> 0
    58 -> 0
    59 -> 20
    60 -> 0
    61 -> 0
    62 -> 0
    63 -> 0
    64 -> 0
    65 -> 0
    66 -> 0
    67 -> 0
    68 -> 20
    69 -> 0
    70 -> 0
    71 -> 24
    72 -> 0
    73 -> 0
    74 -> 20
    75 -> 0
    76 -> 0
    77 -> 0
    78 -> 0
    79 -> 0
    80 -> 0
    81 -> 0
    82 -> 0
    83 -> 0
    84 -> 0
    85 -> 20
    86 -> 2
    87 -> 24
    88 -> 2
    89 -> 20
    90 -> 0
    91 -> 0
    92 -> 0
    93 -> 0
    94 -> 0
    95 -> 0
    96 -> 0
    97 -> 0
    98 -> 0
    99 -> 0
    100 -> 0
    101 -> 2
    102 -> 53
    103 -> 56
    104 -> 53
    105 -> 2
    106 -> 0
    107 -> 0
    108 -> 0
    109 -> 0
    110 -> 0
    111 -> 0
    112 -> 24
    113 -> 24
    114 -> 24
    115 -> 24
    116 -> 24
    117 -> 24
    118 -> 56
    119 -> 0
    120 -> 56
    121 -> 24
    122 -> 24
    123 -> 24
    124 -> 24
    125 -> 24
    126 -> 24
    127 -> 0
    128 -> 0
    129 -> 0
    130 -> 0
    131 -> 0
    132 -> 0
    133 -> 2
    134 -> 53
    135 -> 56
    136 -> 53
    137 -> 2
    138 -> 0
    139 -> 0
    140 -> 0
    141 -> 0
    142 -> 0
    143 -> 0
    144 -> 0
    145 -> 0
    146 -> 0
    147 -> 0
    148 -> 0
    149 -> 20
    150 -> 2
    151 -> 24
    152 -> 2
    153 -> 20
    154 -> 0
    155 -> 0
    156 -> 0
    157 -> 0
    158 -> 0
    159 -> 0
    160 -> 0
    161 -> 0
    162 -> 0
    163 -> 0
    164 -> 20
    165 -> 0
    166 -> 0
    167 -> 24
    168 -> 0
    169 -> 0
    170 -> 20
    171 -> 0
    172 -> 0
    173 -> 0
    174 -> 0
    175 -> 0
    176 -> 0
    177 -> 0
    178 -> 0
    179 -> 20
    180 -> 0
    181 -> 0
    182 -> 0
    183 -> 24
    184 -> 0
    185 -> 0
    186 -> 0
    187 -> 20
    188 -> 0
    189 -> 0
    190 -> 0
    191 -> 0
    192 -> 0
    193 -> 0
    194 -> 20
    195 -> 0
    196 -> 0
    197 -> 0
    198 -> 0
    199 -> 24
    200 -> 0
    201 -> 0
    202 -> 0
    203 -> 0
    204 -> 20
    205 -> 0
    206 -> 0
    207 -> 0
    208 -> 0
    209 -> 20
    210 -> 0
    211 -> 0
    212 -> 0
    213 -> 0
    214 -> 0
    215 -> 24
    216 -> 0
    217 -> 0
    218 -> 0
    219 -> 0
    220 -> 0
    221 -> 20
    222 -> 0
    223 -> 0
    224 -> 20
    225 -> 0
    226 -> 0
    227 -> 0
    228 -> 0
    229 -> 0
    230 -> 0
    231 -> 24
    232 -> 0
    233 -> 0
    234 -> 0
    235 -> 0
    236 -> 0
    237 -> 0
    238 -> 20
    _ -> panic
  }
}

/// Returns the offset necessary to reach from one ox88 position to another
/// Given a difference in ox88 positions + 0x77
///  17,  0,  0,  0,  0,  0,  0, 16,  0,  0,  0,  0,  0,  0, 15, 0,
///   0, 17,  0,  0,  0,  0,  0, 16,  0,  0,  0,  0,  0, 15,  0, 0,
///   0,  0, 17,  0,  0,  0,  0, 16,  0,  0,  0,  0, 15,  0,  0, 0,
///   0,  0,  0, 17,  0,  0,  0, 16,  0,  0,  0, 15,  0,  0,  0, 0,
///   0,  0,  0,  0, 17,  0,  0, 16,  0,  0, 15,  0,  0,  0,  0, 0,
///   0,  0,  0,  0,  0, 17,  0, 16,  0, 15,  0,  0,  0,  0,  0, 0,
///   0,  0,  0,  0,  0,  0, 17, 16, 15,  0,  0,  0,  0,  0,  0, 0,
///   1,  1,  1,  1,  1,  1,  1,  0, -1, -1,  -1,-1, -1, -1, -1, 0,
///   0,  0,  0,  0,  0,  0,-15,-16,-17,  0,  0,  0,  0,  0,  0, 0,
///   0,  0,  0,  0,  0,-15,  0,-16,  0,-17,  0,  0,  0,  0,  0, 0,
///   0,  0,  0,  0,-15,  0,  0,-16,  0,  0,-17,  0,  0,  0,  0, 0,
///   0,  0,  0,-15,  0,  0,  0,-16,  0,  0,  0,-17,  0,  0,  0, 0,
///   0,  0,-15,  0,  0,  0,  0,-16,  0,  0,  0,  0,-17,  0,  0, 0,
///   0,-15,  0,  0,  0,  0,  0,-16,  0,  0,  0,  0,  0,-17,  0, 0,
/// -15,  0,  0,  0,  0,  0,  0,-16,  0,  0,  0,  0,  0,  0,-17
pub fn rays(difference: Int) {
  case difference {
    0 -> 17
    1 -> 0
    2 -> 0
    3 -> 0
    4 -> 0
    5 -> 0
    6 -> 0
    7 -> 16
    8 -> 0
    9 -> 0
    10 -> 0
    11 -> 0
    12 -> 0
    13 -> 0
    14 -> 15
    15 -> 0
    16 -> 0
    17 -> 17
    18 -> 0
    19 -> 0
    20 -> 0
    21 -> 0
    22 -> 0
    23 -> 16
    24 -> 0
    25 -> 0
    26 -> 0
    27 -> 0
    28 -> 0
    29 -> 15
    30 -> 0
    31 -> 0
    32 -> 0
    33 -> 0
    34 -> 17
    35 -> 0
    36 -> 0
    37 -> 0
    38 -> 0
    39 -> 16
    40 -> 0
    41 -> 0
    42 -> 0
    43 -> 0
    44 -> 15
    45 -> 0
    46 -> 0
    47 -> 0
    48 -> 0
    49 -> 0
    50 -> 0
    51 -> 17
    52 -> 0
    53 -> 0
    54 -> 0
    55 -> 16
    56 -> 0
    57 -> 0
    58 -> 0
    59 -> 15
    60 -> 0
    61 -> 0
    62 -> 0
    63 -> 0
    64 -> 0
    65 -> 0
    66 -> 0
    67 -> 0
    68 -> 17
    69 -> 0
    70 -> 0
    71 -> 16
    72 -> 0
    73 -> 0
    74 -> 15
    75 -> 0
    76 -> 0
    77 -> 0
    78 -> 0
    79 -> 0
    80 -> 0
    81 -> 0
    82 -> 0
    83 -> 0
    84 -> 0
    85 -> 17
    86 -> 0
    87 -> 16
    88 -> 0
    89 -> 15
    90 -> 0
    91 -> 0
    92 -> 0
    93 -> 0
    94 -> 0
    95 -> 0
    96 -> 0
    97 -> 0
    98 -> 0
    99 -> 0
    100 -> 0
    101 -> 0
    102 -> 17
    103 -> 16
    104 -> 15
    105 -> 0
    106 -> 0
    107 -> 0
    108 -> 0
    109 -> 0
    110 -> 0
    111 -> 0
    112 -> 1
    113 -> 1
    114 -> 1
    115 -> 1
    116 -> 1
    117 -> 1
    118 -> 1
    119 -> 0
    120 -> -1
    121 -> -1
    122 -> -1
    123 -> -1
    124 -> -1
    125 -> -1
    126 -> -1
    127 -> 0
    128 -> 0
    129 -> 0
    130 -> 0
    131 -> 0
    132 -> 0
    133 -> 0
    134 -> -15
    135 -> -16
    136 -> -17
    137 -> 0
    138 -> 0
    139 -> 0
    140 -> 0
    141 -> 0
    142 -> 0
    143 -> 0
    144 -> 0
    145 -> 0
    146 -> 0
    147 -> 0
    148 -> 0
    149 -> -15
    150 -> 0
    151 -> -16
    152 -> 0
    153 -> -17
    154 -> 0
    155 -> 0
    156 -> 0
    157 -> 0
    158 -> 0
    159 -> 0
    160 -> 0
    161 -> 0
    162 -> 0
    163 -> 0
    164 -> -15
    165 -> 0
    166 -> 0
    167 -> -16
    168 -> 0
    169 -> 0
    170 -> -17
    171 -> 0
    172 -> 0
    173 -> 0
    174 -> 0
    175 -> 0
    176 -> 0
    177 -> 0
    178 -> 0
    179 -> -15
    180 -> 0
    181 -> 0
    182 -> 0
    183 -> -16
    184 -> 0
    185 -> 0
    186 -> 0
    187 -> -17
    188 -> 0
    189 -> 0
    190 -> 0
    191 -> 0
    192 -> 0
    193 -> 0
    194 -> -15
    195 -> 0
    196 -> 0
    197 -> 0
    198 -> 0
    199 -> -16
    200 -> 0
    201 -> 0
    202 -> 0
    203 -> 0
    204 -> -17
    205 -> 0
    206 -> 0
    207 -> 0
    208 -> 0
    209 -> -15
    210 -> 0
    211 -> 0
    212 -> 0
    213 -> 0
    214 -> 0
    215 -> -16
    216 -> 0
    217 -> 0
    218 -> 0
    219 -> 0
    220 -> 0
    221 -> -17
    222 -> 0
    223 -> 0
    224 -> -15
    225 -> 0
    226 -> 0
    227 -> 0
    228 -> 0
    229 -> 0
    230 -> 0
    231 -> -16
    232 -> 0
    233 -> 0
    234 -> 0
    235 -> 0
    236 -> 0
    237 -> 0
    238 -> -17
    _ -> panic
  }
}
// END: Constants
