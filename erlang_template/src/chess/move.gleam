import chess/game/castle
import chess/piece
import chess/player
import chess/square
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// Validated from a game
pub type ValidInContext

/// PseudoMoves don't consider checks, only occupancy
pub type Pseudo

pub type Move(context) {
  Move(
    // The minimum amount of information to disambiguate between moves
    // The source of truth is from, to, promotion
    // Castles are represented by king moves
    from: square.Square,
    to: square.Square,
    promotion: Option(piece.PieceSymbol),
    // extra context for calculations
    context: Option(Context),
  )
}

// we don't current actually use this yet
pub type Context {
  Context(
    capture: Option(#(square.Square, piece.Piece)),
    piece: piece.Piece,
    castling: Option(castle.Castle),
    // game hash? there might be collisions though
  )
}

pub fn new_pseudo(
  from from: square.Square,
  to to: square.Square,
  promotion promotion: Option(piece.PieceSymbol),
) -> Move(Pseudo) {
  Move(from:, to:, promotion:, context: None)
}

pub fn new_pseudo_with_context(
  from from: square.Square,
  to to: square.Square,
  promotion promotion: Option(piece.PieceSymbol),
  context context: Option(Context),
) -> Move(Pseudo) {
  Move(from:, to:, promotion:, context:)
}

pub fn new_valid(
  from from: square.Square,
  to to: square.Square,
  promotion promotion: Option(piece.PieceSymbol),
  context context: Option(Context),
) -> Move(ValidInContext) {
  Move(from:, to:, promotion:, context:)
}

pub fn is_quiet(move: Move(ValidInContext)) {
  let assert Some(context) = move.context
  option.is_none(context.capture)
}

pub fn is_capture(move: Move(ValidInContext)) {
  let assert Some(context) = move.context
  option.is_some(context.capture)
}

pub fn is_promotion(move: Move(ValidInContext)) {
  option.is_some(move.promotion)
}

pub fn to_lan(move: Move(a)) {
  square.to_string(move.from)
  <> square.to_string(move.to)
  <> case move.promotion {
    Some(symbol) -> piece.symbol_to_string(symbol) |> string.lowercase
    None -> ""
  }
}

/// Generates a pseudo move from LAN string
/// there's a specific kind of long algebraic notation used by UCI
pub fn from_lan(lan: String) -> Move(Pseudo) {
  let from = string.slice(lan, 0, 2) |> square.from_string
  let to = string.slice(lan, 2, 2) |> square.from_string
  let promotion =
    string.slice(lan, 4, 1)
    |> piece.symbol_from_string
    |> option.from_result
  case from, to {
    Ok(from), Ok(to) -> new_pseudo(from:, to:, promotion:)
    _, _ -> panic as { lan <> " is an invalid lan" }
  }
}

pub fn encode_pg(move: Move(a)) {
  let to_file = square.file(move.to)
  let to_rank = square.rank(move.to)
  let from_file = square.file(move.from)
  let from_rank = square.rank(move.from)
  let promotion_piece = case move.promotion {
    None -> 0
    Some(piece.Knight) -> 1
    Some(piece.Bishop) -> 2
    Some(piece.Rook) -> 3
    Some(piece.Queen) -> 4
    _ -> panic as "Bad promotion"
  }
  int.bitwise_and(to_file, 0b111)
  |> int.bitwise_or(int.bitwise_and(
    int.bitwise_shift_left(to_rank, 3),
    0b111_000,
  ))
  |> int.bitwise_or(int.bitwise_and(
    int.bitwise_shift_left(from_file, 6),
    0b111_000_000,
  ))
  |> int.bitwise_or(int.bitwise_and(
    int.bitwise_shift_left(from_rank, 9),
    0b111_000_000_000,
  ))
  |> int.bitwise_or(int.bitwise_and(
    int.bitwise_shift_left(promotion_piece, 12),
    0b111_000_000_000_000,
  ))
}

/// Decode a move according to the polyglot format:
/// http://hgm.nubati.net/book_format.html
///
///
pub fn decode_pg(move: Int) -> Result(Move(Pseudo), Nil) {
  let to_file = int.bitwise_and(move, 0b111)
  let to_rank = int.bitwise_and(move, 0b111_000) |> int.bitwise_shift_right(3)
  let from_file =
    int.bitwise_and(move, 0b111_000_000) |> int.bitwise_shift_right(6)
  let from_rank =
    int.bitwise_and(move, 0b111_000_000_000) |> int.bitwise_shift_right(9)
  let promotion_piece =
    int.bitwise_and(move, 0b111_000_000_000_000) |> int.bitwise_shift_right(12)

  use from <- result.try(square.from_rank_file(from_rank, from_file))
  use to <- result.try(square.from_rank_file(to_rank, to_file))
  use promotion <- result.try(case promotion_piece {
    0 -> Ok(None)
    1 -> Ok(Some(piece.Knight))
    2 -> Ok(Some(piece.Bishop))
    3 -> Ok(Some(piece.Rook))
    4 -> Ok(Some(piece.Queen))
    _ -> Error(Nil)
  })

  Ok(Move(from, to, promotion, None))
}

/// Compares equality but don't compare the context
pub fn equal(move_1: Move(a), move_2: Move(b)) {
  move_1.from == move_2.from
  && move_1.to == move_2.to
  && move_1.promotion == move_2.promotion
}

pub fn rook_castle(
  player: player.Player,
  castle: castle.Castle,
) -> Move(ValidInContext) {
  let rank = square.player_rank(player)
  let from_file = castle.rook_from_file(castle)
  let to_file = case castle {
    castle.KingSide -> 5
    castle.QueenSide -> 3
  }
  let assert Ok(from) = square.from_rank_file(rank, from_file)
  let assert Ok(to) = square.from_rank_file(rank, to_file)
  let context =
    Some(Context(
      capture: None,
      piece: piece.Piece(player, piece.Rook),
      castling: None,
    ))
  new_valid(from:, to:, promotion: option.None, context:)
}

pub fn king_castle(
  player: player.Player,
  castle: castle.Castle,
) -> Move(ValidInContext) {
  let rank = square.player_rank(player)

  let to_file = case castle {
    castle.KingSide -> 6
    castle.QueenSide -> 2
  }

  let assert Ok(from) = square.from_rank_file(rank, square.king_file)
  let assert Ok(to) = square.from_rank_file(rank, to_file)

  let context =
    Some(Context(
      capture: None,
      piece: piece.Piece(player, piece.King),
      castling: Some(castle),
    ))
  new_valid(from:, to:, promotion: option.None, context:)
}
