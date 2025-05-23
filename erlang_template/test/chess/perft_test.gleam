import chess/game
import chess/util/perft
import gleeunit/should

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

pub fn perft_defend_promote_test() {
  let assert Ok(game) =
    game.load_fen("8/8/8/7p/8/2b2kPp/3p1P2/4N1K1 b - - 1 63")
  perft.perft(game, 1) |> should.equal(7)
  perft.perft(game, 2) |> should.equal(38)
  perft.perft(game, 3) |> should.equal(747)
  perft.perft(game, 4) |> should.equal(5168)
  perft.perft(game, 5) |> should.equal(98_239)
}

// Extra tests from:
// https://gist.github.com/peterellisjones/8c46c28141c162d1d8a0f0badbc9cff9

pub fn perft_extras_1_test() {
  let assert Ok(game) = game.load_fen("r6r/1b2k1bq/8/8/7B/8/8/R3K2R b KQ - 3 2")
  perft.perft(game, 1) |> should.equal(8)
}

pub fn perft_extras_2_test() {
  let assert Ok(game) = game.load_fen("8/8/8/2k5/2pP4/8/B7/4K3 b - d3 0 3")
  perft.perft(game, 1) |> should.equal(8)
}

pub fn perft_extras_3_test() {
  let assert Ok(game) =
    game.load_fen("r1bqkbnr/pppppppp/n7/8/8/P7/1PPPPPPP/RNBQKBNR w KQkq - 2 2")
  perft.perft(game, 1) |> should.equal(19)
}

pub fn perft_extras_4_test() {
  let assert Ok(game) =
    game.load_fen(
      "r3k2r/p1pp1pb1/bn2Qnp1/2qPN3/1p2P3/2N5/PPPBBPPP/R3K2R b KQkq - 3 2",
    )
  perft.perft(game, 1) |> should.equal(5)
}

pub fn perft_extras_5_test() {
  let assert Ok(game) =
    game.load_fen(
      "2kr3r/p1ppqpb1/bn2Qnp1/3PN3/1p2P3/2N5/PPPBBPPP/R3K2R b KQ - 3 2",
    )
  perft.perft(game, 1) |> should.equal(44)
}

pub fn perft_extras_6_test() {
  let assert Ok(game) =
    game.load_fen("rnb2k1r/pp1Pbppp/2p5/q7/2B5/8/PPPQNnPP/RNB1K2R w KQ - 3 9")
  perft.perft(game, 1) |> should.equal(39)
}

pub fn perft_extras_7_test() {
  let assert Ok(game) = game.load_fen("2r5/3pk3/8/2P5/8/2K5/8/8 w - - 5 4")
  perft.perft(game, 1) |> should.equal(9)
}

pub fn perft_extras_8_test() {
  let assert Ok(game) =
    game.load_fen("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8")
  perft.perft(game, 3) |> should.equal(62_379)
}

pub fn perft_extras_9_test() {
  let assert Ok(game) =
    game.load_fen(
      "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10",
    )
  perft.perft(game, 3) |> should.equal(89_890)
}

pub fn perft_extras_10_test() {
  let assert Ok(game) = game.load_fen("3k4/3p4/8/K1P4r/8/8/8/8 b - - 0 1")
  perft.perft(game, 6) |> should.equal(1_134_888)
}

pub fn perft_extras_11_test() {
  let assert Ok(game) = game.load_fen("8/8/4k3/8/2p5/8/B2P2K1/8 w - - 0 1")
  perft.perft(game, 6) |> should.equal(1_015_133)
}

pub fn perft_extras_12_test() {
  let assert Ok(game) = game.load_fen("8/8/1k6/2b5/2pP4/8/5K2/8 b - d3 0 1")
  perft.perft(game, 6) |> should.equal(1_440_467)
}

pub fn perft_extras_13_test() {
  let assert Ok(game) = game.load_fen("5k2/8/8/8/8/8/8/4K2R w K - 0 1")
  perft.perft(game, 6) |> should.equal(661_072)
}

pub fn perft_extras_14_test() {
  let assert Ok(game) = game.load_fen("3k4/8/8/8/8/8/8/R3K3 w Q - 0 1")
  perft.perft(game, 6) |> should.equal(803_711)
}

pub fn perft_extras_15_test() {
  let assert Ok(game) =
    game.load_fen("r3k2r/1b4bq/8/8/8/8/7B/R3K2R w KQkq - 0 1")
  perft.perft(game, 4) |> should.equal(1_274_206)
}

pub fn perft_extras_16_test() {
  let assert Ok(game) =
    game.load_fen("r3k2r/8/3Q4/8/8/5q2/8/R3K2R b KQkq - 0 1")
  perft.perft(game, 4) |> should.equal(1_720_476)
}

pub fn perft_extras_17_test() {
  let assert Ok(game) = game.load_fen("2K2r2/4P3/8/8/8/8/8/3k4 w - - 0 1")
  perft.perft(game, 6) |> should.equal(3_821_001)
}

pub fn perft_extras_18_test() {
  let assert Ok(game) = game.load_fen("8/8/1P2K3/8/2n5/1q6/8/5k2 b - - 0 1")
  perft.perft(game, 5) |> should.equal(1_004_658)
}

pub fn perft_extras_19_test() {
  let assert Ok(game) = game.load_fen("4k3/1P6/8/8/8/8/K7/8 w - - 0 1")
  perft.perft(game, 6) |> should.equal(217_342)
}

pub fn perft_extras_20_test() {
  let assert Ok(game) = game.load_fen("8/P1k5/K7/8/8/8/8/8 w - - 0 1")
  perft.perft(game, 6) |> should.equal(92_683)
}

pub fn perft_extras_21_test() {
  let assert Ok(game) = game.load_fen("K1k5/8/P7/8/8/8/8/8 w - - 0 1")
  perft.perft(game, 6) |> should.equal(2217)
}

pub fn perft_extras_22_test() {
  let assert Ok(game) = game.load_fen("8/k1P5/8/1K6/8/8/8/8 w - - 0 1")
  perft.perft(game, 7) |> should.equal(567_584)
}

pub fn perft_extras_23_test() {
  let assert Ok(game) = game.load_fen("8/8/2k5/5q2/5n2/8/5K2/8 b - - 0 1")
  perft.perft(game, 4) |> should.equal(23_527)
}
