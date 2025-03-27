import chess/player

pub type PieceSymbol {
  Pawn
  Knight
  Bishop
  Rook
  Queen
  King
}

pub type Piece {
  Piece(player: player.Player, symbol: PieceSymbol)
}
