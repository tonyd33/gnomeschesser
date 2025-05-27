import chess/evaluate
import chess/game

pub fn main() {
  let assert Ok(game) =
    game.load_fen(
      "r1bqkbnr/ppp1pppp/2n5/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2",
    )
}
