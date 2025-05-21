import chess/constants_store
import chess/game
import chess/util/perft
import gleeunit/should

pub fn perft_starting_position_test() {
  let store = constants_store.new()
  let assert Ok(game) = game.load_fen(game.start_fen)
  perft.perft(game, 0, store) |> should.equal(1)
  perft.perft(game, 1, store) |> should.equal(20)
  perft.perft(game, 2, store) |> should.equal(400)
  perft.perft(game, 3, store) |> should.equal(8902)
  perft.perft(game, 4, store) |> should.equal(197_281)
}

pub fn perft_kiwipete_test() {
  let store = constants_store.new()
  let assert Ok(game) =
    game.load_fen(
      "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
    )
  perft.perft(game, 1, store) |> should.equal(48)
  perft.perft(game, 2, store) |> should.equal(2039)
  perft.perft(game, 3, store) |> should.equal(97_862)
  //perft.perft(game, 4, store) |> should.equal(4_085_603)
}

pub fn perft_position_3_test() {
  let store = constants_store.new()
  let assert Ok(game) =
    game.load_fen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
  perft.perft(game, 1, store) |> should.equal(14)
  perft.perft(game, 2, store) |> should.equal(191)
  perft.perft(game, 3, store) |> should.equal(2812)
  perft.perft(game, 4, store) |> should.equal(43_238)
  perft.perft(game, 5, store) |> should.equal(674_624)
  //perft.perft(game, 6, store) |> should.equal(11_030_083)
}
