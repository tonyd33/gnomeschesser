import chess/player
import gleam/int
import gleam/result
import gleam/string
import util/direction

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

pub fn to_string(piece: Piece) -> String {
  case piece.player {
    player.White -> string.uppercase(symbol_to_string(piece.symbol))
    player.Black -> string.lowercase(symbol_to_string(piece.symbol))
  }
}

pub fn from_string(string: String) -> Result(Piece, Nil) {
  use symbol <- result.map(symbol_from_string(string))
  case string.uppercase(string) == string {
    True -> Piece(player.White, symbol)
    False -> Piece(player.Black, symbol)
  }
}

pub fn symbol_to_string(symbol: PieceSymbol) -> String {
  case symbol {
    Pawn -> "P"
    Knight -> "N"
    Bishop -> "B"
    Rook -> "R"
    Queen -> "Q"
    King -> "K"
  }
}

pub fn symbol_from_string(string: String) -> Result(PieceSymbol, Nil) {
  case string |> string.lowercase {
    "p" -> Ok(Pawn)
    "n" -> Ok(Knight)
    "b" -> Ok(Bishop)
    "r" -> Ok(Rook)
    "q" -> Ok(Queen)
    "k" -> Ok(King)
    _ -> Error(Nil)
  }
}

pub fn pawn_direction(player: player.Player) {
  case player {
    player.White -> direction.Up
    player.Black -> direction.Down
  }
}

/// These should be based on the material weights
/// TODO: see if comparing directly is faster
pub fn compare_symbol(symbol1: PieceSymbol, symbol2: PieceSymbol) {
  int.compare(
    case symbol1 {
      King -> 0
      Queen -> 5
      Rook -> 4
      Bishop -> 3
      Knight -> 2
      Pawn -> 1
    },
    case symbol2 {
      King -> 0
      Queen -> 5
      Rook -> 4
      Bishop -> 3
      Knight -> 2
      Pawn -> 1
    },
  )
}
