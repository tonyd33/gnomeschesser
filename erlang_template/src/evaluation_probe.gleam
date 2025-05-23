import chess/evaluate
import chess/evaluate/common
import chess/game

pub fn main() {
  let assert Ok(game) =
    game.load_fen("n2bk2n/pppppppp/5b2/8/1N6/8/PPPPPPPP/3BKB1N b KQkq - 1 1")
  let scores = evaluate.batch_scores(game)
  echo scores
  echo evaluate.phase(game, scores)
}
