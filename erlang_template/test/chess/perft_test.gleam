import chess/debug/perft
import chess/game
import gleam/erlang
import gleam/float
import gleam/int
import gleam/io
import gleeunit/should

pub type Timeout {
  Timeout(Float, fn() -> Nil)
}

pub fn perft_starting_position_test() {
  let assert Ok(game) = game.load_fen(game.start_fen)
  perft.perft(game, 0) |> should.equal(1)
  perft.perft(game, 1) |> should.equal(20)
  perft.perft(game, 2) |> should.equal(400)
  perft.perft(game, 3) |> should.equal(8902)
  perft.perft(game, 4) |> should.equal(197_281)
}

pub fn perft_kiwipete_test() {
  let assert Ok(game) =
    game.load_fen(
      "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
    )
  perft.perft(game, 1) |> should.equal(48)
  perft.perft(game, 2) |> should.equal(2039)
  perft.perft(game, 3) |> should.equal(97_862)
  //perft.perft(game, 4) |> should.equal(4_085_603)
}

pub fn perft_position_3_test() {
  let assert Ok(game) =
    game.load_fen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
  perft.perft(game, 1) |> should.equal(14)
  perft.perft(game, 2) |> should.equal(191)
  perft.perft(game, 3) |> should.equal(2812)
  perft.perft(game, 4) |> should.equal(43_238)
  perft.perft(game, 5) |> should.equal(674_624)
  //perft.perft(game, 6) |> should.equal(11_030_083)
}

pub fn perft_timing_test_() {
  use <- Timeout(10.0)
  let assert Ok(game) = game.load_fen(game.start_fen)
  let start = erlang.system_time(erlang.Millisecond)
  perft.perft(game, 4)
  |> should.equal(197_281)
  let end = erlang.system_time(erlang.Millisecond)
  io.println_error("Perft depth 4 in: " <> int.to_string(end - start) <> " ms")
  io.println_error(
    "Perft depth 4 in: "
    <> float.to_string(197_281.0 /. int.to_float(end - start) *. 1000.0)
    <> " nodes/second",
  )
  Nil
}
