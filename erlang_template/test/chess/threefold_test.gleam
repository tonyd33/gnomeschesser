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

  Nil
}
