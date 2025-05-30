import gleam/list
import chess/tables
import chess/game

pub fn main() {
  let assert Ok(game) = game.load_fen(game.start_fen)
  echo "I am alive"
  let hash = game.hash(game)
  echo list.filter(tables.shit, fn(x) {
    x.0 == hash
  })
  echo "Done"
}
