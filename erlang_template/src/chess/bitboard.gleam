import chess/piece
import chess/player
import chess/square
import gleam/bool
import gleam/int
import gleam/list
import util/direction

pub type BitBoard =
  Int

// Maybe we just turn this into a dict? idk
pub type GameBitboard {
  GameBitboard(
    white_pawns: BitBoard,
    white_knights: BitBoard,
    white_bishops: BitBoard,
    white_rooks: BitBoard,
    white_queens: BitBoard,
    white_king: BitBoard,
    black_pawns: BitBoard,
    black_knights: BitBoard,
    black_bishops: BitBoard,
    black_rooks: BitBoard,
    black_queens: BitBoard,
    black_king: BitBoard,
  )
}

/// TODO: we should consider pre-calculating these and caching them
pub fn get_bitboard_all(game_bitboard: GameBitboard) -> BitBoard {
  game_bitboard.white_pawns
  |> int.bitwise_or(game_bitboard.white_rooks)
  |> int.bitwise_or(game_bitboard.white_knights)
  |> int.bitwise_or(game_bitboard.white_bishops)
  |> int.bitwise_or(game_bitboard.white_queens)
  |> int.bitwise_or(game_bitboard.white_king)
  |> int.bitwise_or(game_bitboard.black_pawns)
  |> int.bitwise_or(game_bitboard.black_rooks)
  |> int.bitwise_or(game_bitboard.black_knights)
  |> int.bitwise_or(game_bitboard.black_bishops)
  |> int.bitwise_or(game_bitboard.black_queens)
  |> int.bitwise_or(game_bitboard.black_king)
}

pub fn get_bitboard_player(
  game_bitboard: GameBitboard,
  player: player.Player,
) -> BitBoard {
  case player {
    player.White ->
      game_bitboard.white_pawns
      |> int.bitwise_or(game_bitboard.white_rooks)
      |> int.bitwise_or(game_bitboard.white_knights)
      |> int.bitwise_or(game_bitboard.white_bishops)
      |> int.bitwise_or(game_bitboard.white_queens)
      |> int.bitwise_or(game_bitboard.white_king)
    player.Black ->
      game_bitboard.black_pawns
      |> int.bitwise_or(game_bitboard.black_rooks)
      |> int.bitwise_or(game_bitboard.black_knights)
      |> int.bitwise_or(game_bitboard.black_bishops)
      |> int.bitwise_or(game_bitboard.black_queens)
      |> int.bitwise_or(game_bitboard.black_king)
  }
}

pub fn set_bitboard_piece(
  game_bitboard: GameBitboard,
  bitboard: BitBoard,
  piece: piece.Piece,
) -> GameBitboard {
  case piece {
    piece.Piece(player.White, piece.Pawn) ->
      GameBitboard(..game_bitboard, white_pawns: bitboard)
    piece.Piece(player.White, piece.Rook) ->
      GameBitboard(..game_bitboard, white_rooks: bitboard)
    piece.Piece(player.White, piece.Knight) ->
      GameBitboard(..game_bitboard, white_knights: bitboard)
    piece.Piece(player.White, piece.Bishop) ->
      GameBitboard(..game_bitboard, white_bishops: bitboard)
    piece.Piece(player.White, piece.Queen) ->
      GameBitboard(..game_bitboard, white_queens: bitboard)
    piece.Piece(player.White, piece.King) ->
      GameBitboard(..game_bitboard, white_king: bitboard)
    piece.Piece(player.Black, piece.Pawn) ->
      GameBitboard(..game_bitboard, black_pawns: bitboard)
    piece.Piece(player.Black, piece.Rook) ->
      GameBitboard(..game_bitboard, black_rooks: bitboard)
    piece.Piece(player.Black, piece.Knight) ->
      GameBitboard(..game_bitboard, black_knights: bitboard)
    piece.Piece(player.Black, piece.Bishop) ->
      GameBitboard(..game_bitboard, black_bishops: bitboard)
    piece.Piece(player.Black, piece.Queen) ->
      GameBitboard(..game_bitboard, black_queens: bitboard)
    piece.Piece(player.Black, piece.King) ->
      GameBitboard(..game_bitboard, black_king: bitboard)
  }
}

pub fn get_bitboard_piece(
  game_bitboard: GameBitboard,
  piece: piece.Piece,
) -> BitBoard {
  case piece {
    piece.Piece(player.White, piece.Pawn) -> game_bitboard.white_pawns
    piece.Piece(player.White, piece.Rook) -> game_bitboard.white_rooks
    piece.Piece(player.White, piece.Knight) -> game_bitboard.white_knights
    piece.Piece(player.White, piece.Bishop) -> game_bitboard.white_bishops
    piece.Piece(player.White, piece.Queen) -> game_bitboard.white_queens
    piece.Piece(player.White, piece.King) -> game_bitboard.white_king
    piece.Piece(player.Black, piece.Pawn) -> game_bitboard.black_pawns
    piece.Piece(player.Black, piece.Rook) -> game_bitboard.black_rooks
    piece.Piece(player.Black, piece.Knight) -> game_bitboard.black_knights
    piece.Piece(player.Black, piece.Bishop) -> game_bitboard.black_bishops
    piece.Piece(player.Black, piece.Queen) -> game_bitboard.black_queens
    piece.Piece(player.Black, piece.King) -> game_bitboard.black_king
  }
}

/// Move the pieces on the bitboard a certain direction
/// from the perspective of white
pub fn move(
  bitboard: BitBoard,
  direction: direction.Direction,
  amount: Int,
) -> BitBoard {
  let assert True = amount >= 0
  use <- bool.guard(amount == 0, bitboard)
  use <- bool.guard(amount > 8, 0x00)

  // We use a mask for the leftward/rightward shifting
  // As well as truncating any extra digits
  let mask = {
    let right_mask = fn(x) {
      case x {
        1 ->
          0b11111110_11111110_11111110_11111110_11111110_11111110_11111110_11111110
        2 ->
          0b11111100_11111100_11111100_11111100_11111100_11111100_11111100_11111100
        3 ->
          0b11111000_11111000_11111000_11111000_11111000_11111000_11111000_11111000
        4 ->
          0b11110000_11110000_11110000_11110000_11110000_11110000_11110000_11110000
        5 ->
          0b11100000_11100000_11100000_11100000_11100000_11100000_11100000_11100000
        6 ->
          0b11000000_11000000_11000000_11000000_11000000_11000000_11000000_11000000
        7 ->
          0b10000000_10000000_10000000_10000000_10000000_10000000_10000000_10000000
        _ -> panic
      }
    }
    case direction {
      direction.Left -> right_mask(8 - amount) |> int.bitwise_not
      direction.Right -> right_mask(amount)
      _ -> 0xFFFF_FFFF_FFFF_FFFF
    }
  }
  case direction {
    direction.Up -> int.bitwise_shift_left(bitboard, 8 * amount)
    direction.Down -> int.bitwise_shift_right(bitboard, 8 * amount)
    direction.Left ->
      // We shift right, since the board starts at the bottom left then to the right
      // So shift_right means it moves towards the least significant digit
      int.bitwise_shift_right(bitboard, amount)
    direction.Right ->
      // We shift right, since the board starts at the bottom left then to the right
      // So shift_left means it moves away the least significant digit
      int.bitwise_shift_left(bitboard, amount)
  }
  // Some guaranteed (and hopefully cheap) truncation
  |> int.bitwise_and(mask)
}

/// This function kinda sucks, see if there's an arithmetic way of crunching to ox88
pub fn to_squares(bitboard: BitBoard) -> List(square.Square) {
  // This tries every bit, not sure if there's a better and cheaper way
  [
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
    22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59,
    60, 61, 62, 63,
  ]
  |> list.filter_map(fn(bit_digit) {
    use <- bool.guard(
      0 == int.bitwise_and(bitboard, int.bitwise_shift_left(0b1, bit_digit)),
      Error(Nil),
    )
    let rank = bit_digit / 8
    let file = bit_digit % 8
    square.from_rank_file(rank, file)
  })
}

pub fn from_square(square: square.Square) -> BitBoard {
  let rank = square.rank(square)
  let file = square.file(square)

  let bit = int.bitwise_shift_left(1, rank * 8 + file)
  bit
}

pub fn from_pieces(pieces: List(#(square.Square, piece.Piece))) -> GameBitboard {
  GameBitboard(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
  |> list.fold(pieces, _, fn(game_bitboard, piece) {
    let #(square, piece) = piece
    let bitboard = from_square(square)
    case piece {
      piece.Piece(player.White, piece.Pawn) ->
        GameBitboard(
          ..game_bitboard,
          white_pawns: int.bitwise_or(game_bitboard.white_pawns, bitboard),
        )
      piece.Piece(player.White, piece.Rook) ->
        GameBitboard(
          ..game_bitboard,
          white_rooks: int.bitwise_or(game_bitboard.white_rooks, bitboard),
        )
      piece.Piece(player.White, piece.Knight) ->
        GameBitboard(
          ..game_bitboard,
          white_knights: int.bitwise_or(game_bitboard.white_knights, bitboard),
        )
      piece.Piece(player.White, piece.Bishop) ->
        GameBitboard(
          ..game_bitboard,
          white_bishops: int.bitwise_or(game_bitboard.white_bishops, bitboard),
        )
      piece.Piece(player.White, piece.Queen) ->
        GameBitboard(
          ..game_bitboard,
          white_queens: int.bitwise_or(game_bitboard.white_queens, bitboard),
        )
      piece.Piece(player.White, piece.King) ->
        GameBitboard(
          ..game_bitboard,
          white_king: int.bitwise_or(game_bitboard.white_king, bitboard),
        )
      piece.Piece(player.Black, piece.Pawn) ->
        GameBitboard(
          ..game_bitboard,
          black_pawns: int.bitwise_or(game_bitboard.black_pawns, bitboard),
        )
      piece.Piece(player.Black, piece.Rook) ->
        GameBitboard(
          ..game_bitboard,
          black_rooks: int.bitwise_or(game_bitboard.black_rooks, bitboard),
        )
      piece.Piece(player.Black, piece.Knight) ->
        GameBitboard(
          ..game_bitboard,
          black_knights: int.bitwise_or(game_bitboard.black_knights, bitboard),
        )
      piece.Piece(player.Black, piece.Bishop) ->
        GameBitboard(
          ..game_bitboard,
          black_bishops: int.bitwise_or(game_bitboard.black_bishops, bitboard),
        )
      piece.Piece(player.Black, piece.Queen) ->
        GameBitboard(
          ..game_bitboard,
          black_queens: int.bitwise_or(game_bitboard.black_queens, bitboard),
        )
      piece.Piece(player.Black, piece.King) ->
        GameBitboard(
          ..game_bitboard,
          black_king: int.bitwise_or(game_bitboard.black_king, bitboard),
        )
    }
  })
}

pub fn pawn_start_rank(player: player.Player) -> BitBoard {
  case player {
    player.White -> 0x0000_0000_0000_FF00
    player.Black -> 0x00FF_0000_0000_0000
  }
}

pub fn pawn_promotion_rank(player: player.Player) -> BitBoard {
  case player {
    player.White -> 0xFF00_0000_0000_0000
    player.Black -> 0x0000_0000_0000_00FF
  }
}

pub fn exclusive_or(
  game_bitboard: GameBitboard,
  piece: piece.Piece,
  bitboard: BitBoard,
) -> GameBitboard {
  get_bitboard_piece(game_bitboard, piece)
  |> int.bitwise_exclusive_or(bitboard)
  |> set_bitboard_piece(game_bitboard, _, piece)
}

pub fn and(
  game_bitboard: GameBitboard,
  piece: piece.Piece,
  bitboard: BitBoard,
) -> GameBitboard {
  get_bitboard_piece(game_bitboard, piece)
  |> int.bitwise_and(bitboard)
  |> set_bitboard_piece(game_bitboard, _, piece)
}

pub fn or(
  game_bitboard: GameBitboard,
  piece: piece.Piece,
  bitboard: BitBoard,
) -> GameBitboard {
  get_bitboard_piece(game_bitboard, piece)
  |> int.bitwise_or(bitboard)
  |> set_bitboard_piece(game_bitboard, _, piece)
}

pub fn map(game_bitboard: GameBitboard, func: fn(BitBoard) -> BitBoard) {
  GameBitboard(
    white_pawns: func(game_bitboard.white_pawns),
    white_knights: func(game_bitboard.white_knights),
    white_bishops: func(game_bitboard.white_bishops),
    white_rooks: func(game_bitboard.white_rooks),
    white_queens: func(game_bitboard.white_queens),
    white_king: func(game_bitboard.white_king),
    black_pawns: func(game_bitboard.black_pawns),
    black_knights: func(game_bitboard.black_knights),
    black_bishops: func(game_bitboard.black_bishops),
    black_rooks: func(game_bitboard.black_rooks),
    black_queens: func(game_bitboard.black_queens),
    black_king: func(game_bitboard.black_king),
  )
}
