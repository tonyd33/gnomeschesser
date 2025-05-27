import chess/game
import gleam/dict

pub type GameHistory =
  dict.Dict(Int, game.Game)

pub const new = dict.new

pub fn is_previous_game(game_history: GameHistory, game: game.Game) -> Bool {
  // History should be tiny, up to maybe 200 entries at most.
  // With a 64-bit hash, we can be certain that collisions will never happen
  // so we don't even need to do a better equality check.
  game_history |> dict.has_key(game.hash(game))
}

pub fn insert(game_history: GameHistory, game: game.Game) -> GameHistory {
  game_history
  |> dict.insert(game.hash(game), game)
}
