import chess/evaluate/common
import chess/game
import chess/piece
import chess/player
import gleam/dict
import gleam/int
import gleam/list

pub fn evaluate(game: game.Game) {
  let blocker_score =
    evaluate_blockers(game, player.White)
    + evaluate_blockers(game, player.Black)
  let attacked_score =
    evaluate_attacked(game, player.White)
    + evaluate_attacked(game, player.Black)
  blocker_score + attacked_score |> int.to_float
}

fn evaluate_blockers(game: game.Game, player: player.Player) {
  let board = game.board(game)
  game.king_blockers(game, player)
  |> dict.fold(0, fn(acc, blocker, pinner) {
    let assert Ok(blocker) = dict.get(board, blocker)
    let assert Ok(pinner) = dict.get(board, pinner)
    case pinner.symbol, blocker.symbol {
      _, piece.Knight -> -50
      piece.Bishop, piece.Rook -> -140
      piece.Rook, piece.Bishop -> -100
      piece.Queen, piece.Queen -> -25
      _, piece.Queen -> -250
      _, piece.Pawn -> -10
      _, _ -> 0
    }
    * common.player(blocker.player)
    + acc
  })
}

fn evaluate_attacked(game: game.Game, player: player.Player) {
  case game.king_attackers(game, player) |> list.length {
    0 -> 0
    1 -> -20
    // double attacks are pretty strong
    x -> x * -40
  }
  * common.player(player)
}
