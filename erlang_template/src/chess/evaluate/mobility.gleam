import chess/evaluate/common
import chess/game
import chess/piece
import chess/player
import chess/square
import gleam/bool
import gleam/dict
import gleam/int
import gleam/list

/// Calculate a [mobility score](https://www.chessprogramming.org/Mobility).
///
/// Roughly, we want to capture the idea that "the more choices we have at
/// our disposal, the stronger our position."
///
/// This is implemented in a similar fashion: for every move, it counts
/// positively towards the mobility score and is weighted by the piece.
///
pub fn score(game: game.Game, phase: Float) {
  // find attacks and pins to the king
  let white_king_blockers = game.king_blockers(game, player.White)
  let black_king_blockers = game.king_blockers(game, player.Black)

  let board = game.board(game)
  let #(midgame, endgame) = {
    use acc, square, piece <- dict.fold(board, #(0, 0))

    let move_count = case piece {
      piece.Piece(_, piece.Pawn) -> 0
      piece.Piece(_, piece.King) -> 0
      piece.Piece(player.White, _) ->
        moves_count(board, white_king_blockers, square, piece)
      piece.Piece(player.Black, _) ->
        moves_count(board, black_king_blockers, square, piece)
    }
    let player = common.player(piece.player)
    case phase {
      x if x >=. 1.0 -> {
        #(acc.0 + midgame(move_count, piece) * player, 0)
      }
      x if x <=. 0.0 -> {
        #(0, acc.1 + endgame(move_count, piece) * player)
      }
      _ -> {
        #(
          acc.0 + midgame(move_count, piece) * player,
          acc.1 + endgame(move_count, piece) * player,
        )
      }
    }
  }
  common.taper(midgame |> int.to_float, endgame |> int.to_float, phase)
}

/// We use this to count the number of moves a piece can make from a square
///
/// There's a lot of logic similar to move generation logic in here, but it's
/// not quite move generation: for example, rooks and bishops get to "xray"
/// through themselves and through queens, and we don't check if this piece
/// can actually even move, given that the king may be in check. However, if
/// the piece is pinned to the king, the piece does indeed lose squares it
/// controls, now only being able to control squares along the pin direction.
///
/// *IMPORTANT*: The piece at `square` should match the `piece` on the board!
/// The reason it's still required is purely for optimization reasons: we use
/// this function when looping over the board, in which we already have the
/// square and piece and don't need to make another lookup on the square to
/// get the piece.
pub fn moves_count(
  board: game.Board,
  king_blockers: dict.Dict(square.Square, square.Square),
  from: square.Square,
  piece: piece.Piece,
) -> Int {
  let go_rays = fn(rays) {
    // If we are pinned down, check if the target square is along the line by:
    // If from is a king blocker:
    //   Keep when:
    //     (to == pinner) or
    //     (from_offset == square.ray_to_offset(from: pinner, to: to).0)
    // Else:
    //   Always keep
    let unpins = case dict.get(king_blockers, from) {
      Ok(pinner) -> fn(to) {
        to == pinner
        || {
          let from_offset: Int = square.ray_to_offset(from: pinner, to: from).0
          from_offset == square.ray_to_offset(from: pinner, to: to).0
        }
      }
      _ -> fn(_) { True }
    }
    use acc, ray <- list.fold(rays, 0)
    use acc, to <- list.fold_until(ray, acc)
    use <- bool.guard(!unpins(to), list.Stop(0))

    case dict.get(board, to), piece.symbol {
      Error(Nil), _ -> list.Continue(acc + 1)
      // If we're a queen and we hit anything, always stop
      Ok(_), piece.Queen -> list.Stop(acc + 1)
      // If we're not a queen and we hit something, xray through it if it's
      // the same piece or its a queen
      Ok(hit_piece), _ if hit_piece == piece || hit_piece.symbol == piece.Queen ->
        list.Continue(acc + 1)
      // Otherwise, stop at the hit piece
      Ok(_), _ -> list.Stop(acc + 1)
    }
  }

  case piece.symbol {
    piece.King -> 0
    piece.Rook -> from |> square.rook_rays |> go_rays
    piece.Bishop -> from |> square.bishop_rays |> go_rays
    piece.Queen -> from |> square.queen_rays |> go_rays
    piece.Knight -> list.length(square.knight_moves(from))
    piece.Pawn -> 0
  }
}

pub fn midgame(nmoves, piece: piece.Piece) -> Int {
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

pub fn endgame(nmoves, piece: piece.Piece) -> Int {
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
