import chess/game
import gleam/bool
import gleam/list

pub fn perft(game: game.Game, depth: Int) {
  use <- bool.guard(depth <= 0, 1)

  game.moves(game)
  |> list.fold(0, fn(acc, move) {
    let assert Ok(game) = game.apply(game, move)
    acc + perft(game, depth - 1)
  })
}
