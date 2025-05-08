import chess/piece
import chess/player
import chess/square
import gleam/int
import gleam/list
import util/direction

pub type BitBoard =
  Int

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

// TODO: we should consider pre-calculating these
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
  case direction {
    direction.Up -> int.bitwise_shift_left(bitboard, 8 * amount)
    direction.Down -> int.bitwise_shift_right(bitboard, 8 * amount)
    direction.Left | direction.Right -> {
      let shift = case direction {
        direction.Left -> int.bitwise_shift_left(_, 1 * amount)
        direction.Right -> int.bitwise_shift_right(_, 1 * amount)
        _ -> panic
      }
      let assert <<
        row_1:size(8),
        row_2:size(8),
        row_3:size(8),
        row_4:size(8),
        row_5:size(8),
        row_6:size(8),
        row_7:size(8),
        row_8:size(8),
      >> = <<bitboard:size(64)>>
      let assert <<bitboard:size(64)>> = <<
        shift(row_1):size(8),
        shift(row_2):size(8),
        shift(row_3):size(8),
        shift(row_4):size(8),
        shift(row_5):size(8),
        shift(row_6):size(8),
        shift(row_7):size(8),
        shift(row_8):size(8),
      >>
      bitboard
    }
  }
  // Some guaranteed (and hopefully cheap) truncation
  |> int.bitwise_and(0xFFFFFFFFFFFFFFFF)
}

pub fn to_squares(bitboard: BitBoard) -> List(square.Square) {
  // This tries every bit, not sure if there's a better and cheaper way
  list.range(0, 63)
  |> list.filter(fn(bit_digit) {
    0 != int.bitwise_and(bitboard, int.bitwise_shift_left(0b1, bit_digit))
  })
  |> list.map(fn(bit_digit) {
    let rank = bit_digit / 8
    let file = 7 - bit_digit % 8
    let assert Ok(square) = square.from_rank_file(rank, file)
    square
  })
}

pub fn from_square(square: square.Square) -> BitBoard {
  let rank = square.rank(square)
  let file = square.file(square)

  let bit = int.bitwise_shift_left(1, { rank * 8 } + { 7 - file })
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
