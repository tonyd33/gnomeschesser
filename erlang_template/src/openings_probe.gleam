import chess/game
import chess/tablebase

pub fn main() {
  let assert Ok(game) = game.load_fen(game.start_fen)
  let tb = tablebase.load()
  echo tablebase.query(tb, game)
}
