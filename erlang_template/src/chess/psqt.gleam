import chess/piece
import chess/player
import chess/square

pub type PSQTPhase {
  MidGame
  EndGame
}

pub fn get_psq_score(
  piece: piece.Piece,
  square: square.Square,
  phase: PSQTPhase,
) {
  case phase {
    MidGame -> get_psq_score_midgame(piece, square)
    EndGame -> get_psq_score_endgame(piece, square)
  }
}

fn get_psq_score_endgame(piece: piece.Piece, square: square.Square) {
  let file = square.file(square)
  let rank = case piece.player {
    player.White -> square.rank(square)
    player.Black -> 7 - square.rank(square)
  }

  let table = case piece.symbol {
    piece.Pawn -> pawn
    piece.Rook -> rook
    piece.Knight -> knight
    piece.Bishop -> bishop
    piece.Queen -> queen
    piece.King -> king_endgame
  }
  let value = index_psqt_table(table, rank, file)

  case piece.player {
    player.White -> value
    player.Black -> -value
  }
}

fn get_psq_score_midgame(piece: piece.Piece, square: square.Square) {
  let file = square.file(square)
  let rank = case piece.player {
    player.White -> square.rank(square)
    player.Black -> 7 - square.rank(square)
  }

  let table = case piece.symbol {
    piece.Pawn -> pawn
    piece.Rook -> rook
    piece.Knight -> knight
    piece.Bishop -> bishop
    piece.Queen -> queen
    piece.King -> king_midgame
  }
  let value = index_psqt_table(table, rank, file)

  case piece.player {
    player.White -> value
    player.Black -> -value
  }
}

fn index_psqt_table(
  table: #(
    #(Int, Int, Int, Int, Int, Int, Int, Int),
    #(Int, Int, Int, Int, Int, Int, Int, Int),
    #(Int, Int, Int, Int, Int, Int, Int, Int),
    #(Int, Int, Int, Int, Int, Int, Int, Int),
    #(Int, Int, Int, Int, Int, Int, Int, Int),
    #(Int, Int, Int, Int, Int, Int, Int, Int),
    #(Int, Int, Int, Int, Int, Int, Int, Int),
    #(Int, Int, Int, Int, Int, Int, Int, Int),
  ),
  rank: Int,
  file: Int,
) {
  let table_row = case rank {
    0 -> table.7
    1 -> table.6
    2 -> table.5
    3 -> table.4
    4 -> table.3
    5 -> table.2
    6 -> table.1
    7 -> table.0
    _ -> panic
  }

  case file {
    0 -> table_row.0
    1 -> table_row.1
    2 -> table_row.2
    3 -> table_row.3
    4 -> table_row.4
    5 -> table_row.5
    6 -> table_row.6
    7 -> table_row.7
    _ -> panic
  }
}

// piece square tables with top left being A8
// from white's perspective (mirrored for black)
// The current values are based on 
// https://www.chessprogramming.org/Simplified_Evaluation_Function#Piece-Square_Tables
// TODO: either we generate our own, or copy stockfish's evaluation function
// https://github.com/GediminasMasaitis/texel-tuner

const pawn = #(
  #(000, 000, 000, 000, 000, 000, 000, 000),
  #(050, 050, 050, 050, 050, 050, 050, 050),
  #(010, 010, 020, 030, 030, 020, 010, 010),
  #(005, 005, 010, 025, 025, 010, 005, 005),
  #(000, 000, 000, 020, 020, 000, 000, 000),
  #(005, -05, -10, 000, 000, -10, -05, 005),
  #(005, 010, 010, -20, -20, 010, 010, 005),
  #(000, 000, 000, 000, 000, 000, 000, 000),
)

const knight = #(
  #(-50, -40, -30, -30, -30, -30, -40, -50),
  #(-40, -20, 0, 0, 0, 0, -20, -40),
  #(-30, 0, 10, 15, 15, 10, 0, -30),
  #(-30, 5, 15, 20, 20, 15, 5, -30),
  #(-30, 0, 15, 20, 20, 15, 0, -30),
  #(-30, 5, 10, 15, 15, 10, 5, -30),
  #(-40, -20, 0, 5, 5, 0, -20, -40),
  #(-50, -40, -30, -30, -30, -30, -40, -50),
)

const bishop = #(
  #(-20, -10, -10, -10, -10, -10, -10, -20),
  #(-10, 0, 0, 0, 0, 0, 0, -10),
  #(-10, 0, 5, 10, 10, 5, 0, -10),
  #(-10, 5, 5, 10, 10, 5, 5, -10),
  #(-10, 0, 10, 10, 10, 10, 0, -10),
  #(-10, 10, 10, 10, 10, 10, 10, -10),
  #(-10, 5, 0, 0, 0, 0, 5, -10),
  #(-20, -10, -10, -10, -10, -10, -10, -20),
)

const rook = #(
  #(0, 0, 0, 0, 0, 0, 0, 0),
  #(5, 10, 10, 10, 10, 10, 10, 5),
  #(-5, 0, 0, 0, 0, 0, 0, -5),
  #(-5, 0, 0, 0, 0, 0, 0, -5),
  #(-5, 0, 0, 0, 0, 0, 0, -5),
  #(-5, 0, 0, 0, 0, 0, 0, -5),
  #(-5, 0, 0, 0, 0, 0, 0, -5),
  #(0, 0, 0, 5, 5, 0, 0, 0),
)

const queen = #(
  #(-20, -10, -10, -5, -5, -10, -10, -20),
  #(-10, 0, 0, 0, 0, 0, 0, -10),
  #(-10, 0, 5, 5, 5, 5, 0, -10),
  #(-5, 0, 5, 5, 5, 5, 0, -5),
  #(0, 0, 5, 5, 5, 5, 0, -5),
  #(-10, 5, 5, 5, 5, 5, 0, -10),
  #(-10, 0, 5, 0, 0, 0, 0, -10),
  #(-20, -10, -10, -5, -5, -10, -10, -20),
)

const king_midgame = #(
  #(-30, -40, -40, -50, -50, -40, -40, -30),
  #(-30, -40, -40, -50, -50, -40, -40, -30),
  #(-30, -40, -40, -50, -50, -40, -40, -30),
  #(-30, -40, -40, -50, -50, -40, -40, -30),
  #(-20, -30, -30, -40, -40, -30, -30, -20),
  #(-10, -20, -20, -20, -20, -20, -20, -10),
  #(20, 20, 0, 0, 0, 0, 20, 20),
  #(20, 30, 10, 0, 0, 10, 30, 20),
)

const king_endgame = #(
  #(-50, -40, -30, -20, -20, -30, -40, -50),
  #(-30, -20, -10, 0, 0, -10, -20, -30),
  #(-30, -10, 20, 30, 30, 20, -10, -30),
  #(-30, -10, 30, 40, 40, 30, -10, -30),
  #(-30, -10, 30, 40, 40, 30, -10, -30),
  #(-30, -10, 20, 30, 30, 20, -10, -30),
  #(-30, -30, 0, 0, 0, 0, -30, -30),
  #(-50, -30, -30, -30, -30, -30, -30, -50),
)
