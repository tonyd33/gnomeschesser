import chess/game
import chess/move
import chess/table.{table}
import gleam/dict
import gleam/io
import gleam/list
import gleam/result

pub fn main() {
  let assert Ok(game) = game.load_fen(game.start_fen)
  let hash = game.hash(game)
  let tbl = dict.from_list(table)
  let encoded_moves = dict.get(tbl, hash)
  encoded_moves
  |> result.unwrap([])
  |> list.map(move.decode_pg)
  |> list.map(result.map(_, move.to_lan))
  |> list.each(io.debug)
}
