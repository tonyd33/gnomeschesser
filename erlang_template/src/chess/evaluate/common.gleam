import chess/piece
import chess/player

pub type Stage {
  MidGame
  EndGame
}

pub type SidedScore {
  SidedScore(white: Int, black: Int)
}

pub fn piece_symbol_mg(symbol: piece.PieceSymbol) -> Int {
  case symbol {
    piece.Pawn -> 124
    piece.Knight -> 781
    piece.Bishop -> 825
    piece.Rook -> 1276
    piece.Queen -> 2538
    piece.King -> 0
  }
}

pub fn piece_symbol_eg(symbol: piece.PieceSymbol) -> Int {
  case symbol {
    piece.Pawn -> 206
    piece.Knight -> 854
    piece.Bishop -> 915
    piece.Rook -> 1380
    piece.Queen -> 2682
    piece.King -> 0
  }
}

/// The sign of each player in evaluations
pub fn player(player: player.Player) -> Int {
  case player {
    player.White -> 1
    player.Black -> -1
  }
}

pub fn add_sided_score(s1: SidedScore, s2: SidedScore) {
  SidedScore(white: s1.white + s2.white, black: s1.black + s2.black)
}

pub fn flatten_sided_score(s: SidedScore) -> Int {
  { s.white * player(player.White) } + { s.black * player(player.Black) }
}
