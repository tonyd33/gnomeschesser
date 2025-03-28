import chess/game

/// Standard Algebraic Notation
/// https://en.wikipedia.org/wiki/Algebraic_notation_(chess)
pub type SAN =
  String

pub type Move =
  SAN

pub fn is_capture(move: Move) -> Bool {
  todo
}

pub fn is_promotion(move: Move) -> Bool {
  todo
}

pub fn is_en_passant(move: Move) -> Bool {
  todo
}

pub fn is_kingside_castle(move: Move) -> Bool {
  todo
}

pub fn is_queenside_castle(move: Move) -> Bool {
  todo
}

pub fn to_san(move: Move) -> String {
  todo
}

pub fn from_san(san: String, game: game.Game) -> Result(Move, Nil) {
  todo
}

pub fn apply(move: Move, game: game.Game) -> Result(game.Game, Nil) {
  todo
}

pub fn moves(game: game.Game) -> List(Move) {
  todo
}
