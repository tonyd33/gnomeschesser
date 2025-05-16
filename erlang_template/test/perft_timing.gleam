import chess/game
import chess/util/perft
import glychee/benchmark
import glychee/configuration

type Arguments {
  Arguments(game: game.Game, depth: Int)
}

pub fn main() {
  configuration.initialize()
  configuration.set_pair(configuration.Warmup, 2)
  configuration.set_pair(configuration.Parallel, 2)
  configuration.set_pair(configuration.Time, 10)

  let assert Ok(starting) = game.load_fen(game.start_fen)
  let assert Ok(kiwipete) =
    game.load_fen(
      "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
    )
  let assert Ok(midgame_1) =
    game.load_fen(
      "rnb1kb1r/pp3ppp/2ppp3/4P1N1/3P4/3B1P2/PPP4P/RN1QK2n b Qkq - 1 10",
    )
  // Run the benchmarks
  benchmark.run(
    [
      benchmark.Function(label: "perft", callable: fn(test_data: Arguments) {
        fn() { perft.perft(test_data.game, test_data.depth) }
      }),
    ],
    [
      benchmark.Data(
        label: "starting depth 4",
        data: Arguments(game: starting, depth: 4),
      ),
      benchmark.Data(
        label: "kiwipete depth 3",
        data: Arguments(game: kiwipete, depth: 3),
      ),
      benchmark.Data(
        label: "midgame_1 depth 4",
        data: Arguments(game: midgame_1, depth: 4),
      ),
    ],
  )
}
