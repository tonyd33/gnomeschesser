import chess/game.{type Game}
import chess/move.{type Move, type ValidInContext}
import chess/tablebase/data
import gleam/dict.{type Dict}
import gleam/list
import gleam/result

pub type Tablebase =
  Dict(Int, List(Int))

pub fn load() -> Tablebase {
  dict.from_list(data.table)
}

/// Query to see if there are any moves for this game in our tablebase.
///
pub fn query(tb: Tablebase, game: Game) -> Result(Move(ValidInContext), Nil) {
  // TODO: Consider also looking up for a mirrored version of the game
  // and returning a mirrored move. Not particularly useful for openings,
  // but may be useful for endings.

  use enc_moves <- result.try(dict.get(tb, game.hash(game)))
  list.filter_map(enc_moves, fn(enc_move) {
    enc_move |> move.decode_pg |> result.try(game.validate_move(_, game))
  })
  |> list.first
}
