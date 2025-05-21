import chess/bitboard
import chess/game
import chess/piece
import chess/player
import gleam/dict
import gleam/int
import gleam/result

pub type GameHistory =
  dict.Dict(game.Hash, game.Game)

pub const new = dict.new

pub fn is_previous_game(game_history: GameHistory, game: game.Game) -> Bool {
  game_history
  |> dict.get(game.hash(game))
  |> result.map(game.equal(_, game))
  |> result.unwrap(False)
}

pub fn insert(game_history: GameHistory, game: game.Game) -> GameHistory {
  // we can clear the previous game if there is a capture or pawn move
  // as those are irreversible moves
  // This also resets the halfmove_clock anyways, so we check if it's 0
  let irreversible = game.halfmove_clock(game) == 0

  case irreversible {
    True -> dict.new()
    False -> game_history
  }
  |> dict.insert(game.hash(game), game)
}
