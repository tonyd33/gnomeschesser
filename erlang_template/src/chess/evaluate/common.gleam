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
