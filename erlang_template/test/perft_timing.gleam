import chess/game
import chess/util/perft
import gleam/erlang
import gleam/float
import gleam/int
import gleam/io

pub fn main() {
  let assert Ok(game) = game.load_fen(game.start_fen)
  let start = erlang.system_time(erlang.Millisecond)
  perft.perft(game, 4)
  let end = erlang.system_time(erlang.Millisecond)
  io.println_error("Perft depth 4 in: " <> int.to_string(end - start) <> " ms")
  io.println_error(
    "Perft depth 4 in: "
    <> float.to_string(197_281.0 /. int.to_float(end - start) *. 1000.0)
    <> " nodes/second",
  )
  Nil
}
