import chess/game
import gleam/bool
import gleam/list

pub fn perft(game: game.Game, depth: Int, store) {
  use <- bool.guard(depth <= 0, 1)

  game.valid_moves(game, store)
  |> list.fold(0, fn(acc, move) {
    let game = game.apply(game, move)
    acc + perft(game, depth - 1, store)
  })
}
