import chess/evaluate/common.{type SidedScore, SidedScore}
import chess/piece
import chess/player

/// Calculate a [mobility score](https://www.chessprogramming.org/Mobility).
///
/// Roughly, we want to capture the idea that "the more choices we have at
/// our disposal, the stronger our position."
///
/// This is implemented in a similar fashion: for every move, it counts
/// positively towards the mobility score and is weighted by the piece.
///
pub fn score(nmoves, piece: piece.Piece, phase) -> Int {
  common.player(piece.player)
  * case phase {
    common.MidGame -> mg(nmoves, piece)
    common.EndGame -> eg(nmoves, piece)
  }
}

pub fn sided_score(nmoves, piece, phase) -> SidedScore {
  let score = case phase {
    common.MidGame -> mg(nmoves, piece)
    common.EndGame -> eg(nmoves, piece)
  }
  case piece.player {
    player.White -> SidedScore(white: score, black: 0)
    player.Black -> SidedScore(white: 0, black: score)
  }
}

fn mg(nmoves, piece: piece.Piece) -> Int {
  case piece.symbol {
    piece.Pawn | piece.King -> 0
    piece.Knight -> 0
    piece.Bishop -> 125 * nmoves
    piece.Rook -> 60 * nmoves
    piece.Queen -> 25 * nmoves
  }
}

fn eg(nmoves, piece: piece.Piece) -> Int {
  case piece.symbol {
    piece.Pawn | piece.King -> 0
    piece.Knight -> 8 * nmoves
    piece.Bishop -> 125 * nmoves
    piece.Rook -> 60 * nmoves
    piece.Queen -> 45 * nmoves
  }
}

fn mg_sf(nmoves, piece: piece.Piece) -> Int {
  case piece.symbol {
    piece.Pawn | piece.King -> 0
    piece.Knight ->
      case nmoves {
        0 -> -62
        1 -> -53
        2 -> -12
        3 -> -4
        4 -> 3
        5 -> 13
        6 -> 22
        7 -> 28
        8 -> 33
        _ -> 0
      }
    piece.Bishop ->
      case nmoves {
        0 -> -48
        1 -> -20
        2 -> 16
        3 -> 26
        4 -> 38
        5 -> 51
        6 -> 55
        7 -> 63
        8 -> 63
        9 -> 68
        10 -> 81
        11 -> 81
        12 -> 91
        13 -> 98
        _ -> 0
      }
    piece.Rook ->
      case nmoves {
        0 -> -60
        1 -> -20
        2 -> 2
        3 -> 3
        4 -> 3
        5 -> 11
        6 -> 22
        7 -> 31
        8 -> 40
        9 -> 40
        10 -> 41
        11 -> 48
        12 -> 57
        13 -> 57
        14 -> 62
        _ -> 0
      }
    piece.Queen ->
      case nmoves {
        0 -> -30
        1 -> -12
        2 -> -8
        3 -> -9
        4 -> 20
        5 -> 23
        6 -> 23
        7 -> 35
        8 -> 38
        9 -> 53
        10 -> 64
        11 -> 65
        12 -> 65
        13 -> 66
        14 -> 67
        15 -> 67
        16 -> 72
        17 -> 72
        18 -> 77
        19 -> 79
        20 -> 93
        21 -> 108
        22 -> 108
        23 -> 108
        24 -> 110
        25 -> 114
        26 -> 114
        27 -> 116
        _ -> 0
      }
  }
}

fn eg_sf(nmoves, piece: piece.Piece) -> Int {
  case piece.symbol {
    piece.Pawn | piece.King -> 0
    piece.Knight ->
      case nmoves {
        0 -> -81
        1 -> -56
        2 -> -31
        3 -> -16
        4 -> 5
        5 -> 11
        6 -> 17
        7 -> 20
        8 -> 25
        _ -> 0
      }
    piece.Bishop ->
      case nmoves {
        0 -> -59
        1 -> -23
        2 -> -3
        3 -> 13
        4 -> 24
        5 -> 42
        6 -> 54
        7 -> 57
        8 -> 65
        9 -> 73
        10 -> 78
        11 -> 86
        12 -> 88
        13 -> 97
        _ -> 0
      }
    piece.Rook ->
      case nmoves {
        0 -> -78
        1 -> -17
        2 -> 23
        3 -> 39
        4 -> 70
        5 -> 99
        6 -> 103
        7 -> 121
        8 -> 134
        9 -> 139
        10 -> 158
        11 -> 164
        12 -> 168
        13 -> 169
        14 -> 172
        _ -> 0
      }
    piece.Queen ->
      case nmoves {
        0 -> -48
        1 -> -30
        2 -> -7
        3 -> 19
        4 -> 40
        5 -> 55
        6 -> 59
        7 -> 75
        8 -> 78
        9 -> 96
        10 -> 96
        11 -> 100
        12 -> 121
        13 -> 127
        14 -> 131
        15 -> 133
        16 -> 136
        17 -> 141
        18 -> 147
        19 -> 150
        20 -> 151
        21 -> 168
        22 -> 168
        23 -> 171
        24 -> 182
        25 -> 182
        26 -> 192
        27 -> 219
        _ -> 0
      }
  }
}
