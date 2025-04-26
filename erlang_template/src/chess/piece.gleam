import chess/player
import gleam/string

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

pub fn to_string(piece: Piece) {
  case piece.player {
    player.White -> string.uppercase(piece_symbol_to_string(piece.symbol))
    player.Black -> string.lowercase(piece_symbol_to_string(piece.symbol))
  }
}

pub fn piece_symbol_to_string(symbol: PieceSymbol) {
  case symbol {
    Pawn -> "p"
    Knight -> "n"
    Bishop -> "b"
    Rook -> "r"
    Queen -> "q"
    King -> "k"
  }
}
