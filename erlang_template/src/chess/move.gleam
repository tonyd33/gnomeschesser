import chess/piece
import chess/square
import gleam/option.{type Option, None, Some}
import gleam/string

pub type ValidInContext

pub type Pseudo

pub opaque type Move(context) {
  Move(
    // The minimum amount of information to disambiguate between moves
    // from and to is the source of truth
    // Castles are represented by king moves
    from: square.Square,
    to: square.Square,
    // extra context for calculations
    pawn_context: Option(PawnContext),
    context: Option(MoveContext),
  )
}

pub type PawnContext {
  PawnContext(promotion: Option(piece.PieceSymbol), x_move: Bool)
}

// we don't current actually use this yet
pub type MoveContext {
  MoveContext(capture: Bool)
}

pub fn new_pseudomove_pawn(
  from from: square.Square,
  to to: square.Square,
  pawn_context pawn_context: PawnContext,
) {
  Move(from:, to:, pawn_context: Some(pawn_context), context: None)
}

pub fn new_pseudomove(
  from from: square.Square,
  to to: square.Square,
) -> Move(Pseudo) {
  Move(from:, to:, pawn_context: None, context: None)
}

pub fn get_from(move: Move(a)) {
  move.from
}

pub fn get_to(move: Move(a)) {
  move.to
}

/// TODO: ensure a way that moves that are not pawns don't have access to invalid values of this
pub fn get_promotion(move: Move(a)) {
  option.then(move.pawn_context, fn(pawn_context) { pawn_context.promotion })
}

pub fn is_x_move(move: Move(a)) -> Result(Bool, Nil) {
  move.pawn_context
  |> option.map(fn(pawn_context) { pawn_context.x_move })
  |> option.to_result(Nil)
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
/// TODO: avoid adding pawn context to non-pawn moves (if possible)
pub fn from_lan(lan: String) -> Move(Pseudo) {
  let from = square.from_string(string.slice(lan, 0, 2))
  let to = square.from_string(string.slice(lan, 2, 2))
  let promotion = piece.symbol_from_string(string.slice(lan, 4, 1))

  case from, to {
    Ok(from), Ok(to) -> {
      // we'll generate the pawn context assuming it's a pawn
      // If it's not a pawn, we just won't make use of it
      let x_move = square.file(from) != square.file(to)
      let promotion = option.from_result(promotion)
      let pawn_context = PawnContext(promotion:, x_move:)
      new_pseudomove_pawn(from:, to:, pawn_context:)
    }
    _, _ -> panic as { lan <> " is an invalid lan" }
  }
}

pub fn equal(move_1: Move(a), move_2: Move(b)) {
  move_1.from == move_2.from
  && move_1.to == move_2.to
  && { move_1 |> get_promotion == move_2 |> get_promotion }
}
