import chess/piece
import chess/player

pub type Stage {
  MidGame
  EndGame
}

pub fn piece_symbol_npm(symbol: piece.PieceSymbol) -> Int {
  // stockfish midgame values
  case symbol {
    piece.King | piece.Pawn -> 0
    piece.Knight -> 781
    piece.Bishop -> 825
    piece.Rook -> 1276
    piece.Queen -> 2538
  }
}

// stockfish midgame values
// case symbol {
//   piece.Pawn -> 124
//   piece.Knight -> 781
//   piece.Bishop -> 825
//   piece.Rook -> 1276
//   piece.Queen -> 2538
//   piece.King -> 0
// }

// stockfish endgame values
// case symbol {
//   piece.Pawn -> 206
//   piece.Knight -> 854
//   piece.Bishop -> 915
//   piece.Rook -> 1380
//   piece.Queen -> 2682
//   piece.King -> 0
// }

pub fn piece_mg(piece: piece.Piece) -> Int {
  case piece.symbol {
    piece.Pawn -> 100
    piece.Knight -> 300
    piece.Bishop -> 300
    piece.Rook -> 500
    piece.Queen -> 900
    piece.King -> 0
  }
  * player(piece.player)
}

pub fn piece_eg(piece: piece.Piece) -> Int {
  case piece.symbol {
    piece.Pawn -> 100
    piece.Knight -> 300
    piece.Bishop -> 300
    piece.Rook -> 500
    piece.Queen -> 900
    piece.King -> 0
  }
  * player(piece.player)
}

/// The sign of each player in evaluations
pub fn player(player: player.Player) -> Int {
  case player {
    player.White -> 1
    player.Black -> -1
  }
}

/// Make a smooth transition between mg and eg scores by phase.
/// assumes phase is between 0 and 1
pub fn taper(mg: Float, eg: Float, phase: Float) {
  mg *. phase +. eg *. { 1.0 -. phase }
}
