import chess/game
import chess/player
import chess/square
import gleam/list
import util/array8
import util/direction

pub fn main() {
  let assert Ok(game) =
    game.load_fen("6pk/6pp/5p2/8/3Q4/2P5/8/7K w - - 0 1")
  let wkrps = game.krps(game, player.White)
  echo square.to_string(65)
  echo square.to_string(71)
  list.each(
    [
      direction.Up,
      direction.UpRight,
      direction.Right,
      direction.DownRight,
      direction.Down,
      direction.DownLeft,
      direction.Left,
      direction.UpLeft,
    ],
    fn(dir) { echo #(dir, array8.get(wkrps, direction.number(dir))) },
  )
}
