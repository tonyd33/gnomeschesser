import chess/debug/perft
import chess/game
import gleam/erlang
import gleam/int
import gleam/io
import gleeunit/should

pub type Timeout {
  Timeout(Float, fn() -> Nil)
}

pub fn perft_test_() {
  use <- Timeout(15.0)
  let assert Ok(game) = game.load_fen(game.start_fen)
  perft.perft(game, 0) |> should.equal(1)
  perft.perft(game, 1) |> should.equal(20)
  perft.perft(game, 2) |> should.equal(400)
  perft.perft(game, 3) |> should.equal(8902)
}

pub fn perft_timing_test_() {
  use <- Timeout(30.0)
  let assert Ok(game) = game.load_fen(game.start_fen)
  let start = erlang.system_time(erlang.Millisecond)
  perft.perft(game, 4) |> should.equal(197_281)
  let end = erlang.system_time(erlang.Millisecond)
  io.println_error("Perft depth 4 in: " <> int.to_string(end - start) <> " ms")
  Nil
}
