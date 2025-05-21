import chess/game
import chess/move
import chess/search
import chess/search/game_history
import chess/search/search_state
import gleam/erlang/process
import gleam/list
import gleam/option
import gleam/time/timestamp
import gleeunit/should
import util/yielder

pub fn threefold_test() {
  let assert Ok(game) =
    game.load_fen("k7/8/8/2R5/1R6/PPPP1N2/2q2N2/K7 b - - 0 1")
  let game_history = game_history.new() |> game_history.insert(game)

  search_game_to_depth(game, game_history, 8)
}

fn search_game_to_depth(
  game: game.Game,
  game_history: game_history.GameHistory,
  depth: Int,
) {
  let memo = search_state.new(timestamp.system_time())
  let subject = process.new_subject()
  let _search_pid =
    search.new(
      game,
      memo,
      subject,
      search.SearchOpts(max_depth: option.Some(depth)),
      game_history,
    )

  yielder.repeat(subject)
  |> yielder.fold_until([], fn(acc, subject) {
    case process.receive_forever(subject) {
      search.SearchDone -> list.Stop(acc)
      search.SearchStateUpdate(_) -> list.Continue(acc)
      search.SearchUpdate(best_evaluation:, ..) ->
        best_evaluation.best_line
        |> list.map(move.to_lan)
        |> list.Continue
    }
  })
  |> should.equal(["c2c1", "a1a2", "c1c2", "a2a1"])
}
