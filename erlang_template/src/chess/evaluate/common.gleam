import chess/piece
import chess/player

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

/// Alternative material values from Stockfish. Specifically for using their
/// phase calculations.
/// See: https://hxim.github.io/Stockfish-Evaluation-Guide/ (piece value bonus
/// page)
///
pub fn piece_value_bonus(symbol: piece.PieceSymbol, phase: Stage) -> Int {
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

/// Piece score based on player side
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
