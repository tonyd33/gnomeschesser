import chess/piece
import chess/player
import gleam/bool

pub type Stage {
  MidGame
  EndGame
}

pub fn piece_symbol(symbol: piece.PieceSymbol) -> Int {
  case symbol {
    piece.Pawn -> 100
    piece.Knight -> 300
    piece.Bishop -> 300
    piece.Rook -> 500
    piece.Queen -> 900
    piece.King -> 0
  }
}

pub fn piece_value_bonus_symbol(symbol: piece.PieceSymbol, phase: Stage) -> Int {
  case phase {
    MidGame ->
      case symbol {
        piece.Pawn -> 124
        piece.Knight -> 781
        piece.Bishop -> 825
        piece.Rook -> 1276
        piece.Queen -> 2538
        piece.King -> 0
      }
    EndGame ->
      case symbol {
        piece.Pawn -> 206
        piece.Knight -> 854
        piece.Bishop -> 915
        piece.Rook -> 1380
        piece.Queen -> 2682
        piece.King -> 0
      }
  }
}

/// Alternative material values from Stockfish. Specifically for using their
/// phase calculations.
/// See: https://hxim.github.io/Stockfish-Evaluation-Guide/ (piece value bonus
/// page)
///
pub fn piece_value_bonus(piece: piece.Piece, phase: Stage) -> Int {
  piece_value_bonus_symbol(piece.symbol, phase) * player(piece.player)
}

pub fn non_pawn_piece_value(piece: piece.Piece, phase: Stage) -> SidedScore {
  use <- bool.guard(
    piece.symbol == piece.Pawn || piece.symbol == piece.King,
    empty_sided_score,
  )
  case piece.player {
    player.White ->
      SidedScore(white: piece_value_bonus_symbol(piece.symbol, phase), black: 0)
    player.Black ->
      SidedScore(white: 0, black: piece_value_bonus_symbol(piece.symbol, phase))
  }
}

/// Piece score based on player side
pub fn sided_piece(piece: piece.Piece) -> SidedScore {
  case piece.player {
    player.White -> SidedScore(white: piece_symbol(piece.symbol), black: 0)
    player.Black -> SidedScore(white: 0, black: piece_symbol(piece.symbol))
  }
}

pub fn piece(piece: piece.Piece) -> Int {
  piece_symbol(piece.symbol) * player(piece.player)
}

/// The sign of each player in evaluations
pub fn player(player: player.Player) -> Int {
  case player {
    player.White -> 1
    player.Black -> -1
  }
}

pub type SidedScore {
  SidedScore(white: Int, black: Int)
}

pub const empty_sided_score = SidedScore(0, 0)

pub fn add_sided_score(s1: SidedScore, s2: SidedScore) {
  SidedScore(white: s1.white + s2.white, black: s1.black + s2.black)
}

pub fn flatten_sided_score(s: SidedScore) -> Int {
  { s.white * player(player.White) } + { s.black * player(player.Black) }
}
