import chess/evaluate/common
import chess/evaluate/midgame
import chess/game
import chess/player

pub fn main() {
  let assert Ok(game) =
    game.load_fen(
      "Rnbqkbnr/2pppppp/8/2p1P1r1/8/2N1p3/P1PPPPPP/2BQKBNR w KQkq - 1 1",
    )
  let scores = midgame.psqt(game.pieces(game))
  echo scores
}
