import chess/game
import chess/move
import chess/search
import chess/search/game_history
import chess/search/search_state
import gleam/list
import gleam/option.{Some}
import gleam/result
import gleam/time/timestamp
import gleeunit/should
import util/state

pub fn threefold_test() {
  let assert Ok(game) =
    game.load_fen("k7/8/8/2R5/1R6/PPPP1N2/2q2N2/K7 b - - 0 1")
  let game_history = game_history.new()

  search_game_to_depth(game, game_history, 8)
}

fn search_game_to_depth(
  game: game.Game,
  game_history: game_history.GameHistory,
  depth: Int,
) {
  let memo = search_state.new(timestamp.system_time())
  let #(best_evaluation, _) =
    search.checkpointed_iterative_deepening(
      game,
      1,
      search.SearchOpts(max_depth: Some(depth)),
      game_history,
      fn(_, _, _) { Nil },
    )
    |> state.go(#(fn(_) { False }, memo))

  let moves =
    result.map(best_evaluation, fn(x) { list.map(x.best_line, move.to_lan) })

  should.equal(moves, Ok(["c2c1", "a1a2", "c1c2", "a2a1"]))
}
