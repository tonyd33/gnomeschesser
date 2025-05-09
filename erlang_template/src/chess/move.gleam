import chess/piece
import chess/player
import chess/square
import gleam/option.{type Option, None, Some}
import gleam/string

/// Validated from a game
pub type ValidInContext

/// PseudoMoves don't consider checks, only occupancy
pub type Pseudo

pub opaque type Move(context) {
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
    capture: Bool,
    player: player.Player,
    piece: piece.PieceSymbol,
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

pub fn new_valid(
  from from: square.Square,
  to to: square.Square,
  promotion promotion: Option(piece.PieceSymbol),
  context context: Option(Context),
) -> Move(ValidInContext) {
  Move(from:, to:, promotion:, context:)
}

pub fn get_from(move: Move(a)) {
  move.from
}

pub fn get_to(move: Move(a)) {
  move.to
}

pub fn get_promotion(move: Move(a)) {
  move.promotion
}

pub fn get_context(move: Move(ValidInContext)) {
  let assert Some(context) = move.context
  context
}

pub fn to_lan(move: Move(a)) {
  square.to_string(move.from)
  <> square.to_string(move.to)
  <> case get_promotion(move) {
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

/// Compares equality but don't compare the context
pub fn equal(move_1: Move(a), move_2: Move(b)) {
  move_1.from == move_2.from
  && move_1.to == move_2.to
  && move_1.promotion == move_2.promotion
}
