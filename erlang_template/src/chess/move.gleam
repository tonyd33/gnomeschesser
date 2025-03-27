import chess/game

/// Standard Algebraic Notation
/// https://en.wikipedia.org/wiki/Algebraic_notation_(chess)
pub type SAN =
  String

pub type Move =
  SAN

pub fn is_capture(move: Move, game: game.Game) -> Bool {
  todo
}

pub fn is_promotion(move: Move, game: game.Game) -> Bool {
  todo
}

pub fn is_en_passant(move: Move, game: game.Game) -> Bool {
  todo
}

pub fn is_kingside_castle(move: Move, game: game.Game) -> Bool {
  todo
}

pub fn is_queenside_castle(move: Move, game: game.Game) -> Bool {
  todo
}

pub fn to_san(move: Move) -> String {
  todo
}

pub fn from_san(san: String) -> Move {
  todo
}

pub fn apply(move: Move, game: game.Game) -> Result(game.Game, Nil) {
  todo
}
