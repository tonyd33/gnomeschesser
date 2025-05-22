import bencher
import chess/constants_store
import chess/game
import chess/util/perft
import gleam/dict

type Arguments {
  Arguments(game: game.Game, depth: Int)
}

pub fn main() {
  let store = constants_store.new()

  // https://www.chessprogramming.org/Perft_Results
  let assert Ok(starting) = game.load_fen(game.start_fen)
  let assert Ok(kiwipete) =
    game.load_fen(
      "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
    )
  let assert Ok(position3) =
    game.load_fen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")

  let assert Ok(midgame_1) =
    game.load_fen(
      "rnb1kb1r/pp3ppp/2ppp3/4P1N1/3P4/3B1P2/PPP4P/RN1QK2n b Qkq - 1 10",
    )
  bencher.run(
    dict.from_list([
      #("perft", fn(args: Arguments) { perft.perft(args.game, args.depth, store) }),
    ]),
    [
      bencher.Warmup(2),
      bencher.Parallel(2),
      bencher.Time(20),
      bencher.Inputs(
        [
          #("depth 4: starting pos", Arguments(game: starting, depth: 4)),
          #("depth 3: kiwipete", Arguments(game: kiwipete, depth: 3)),
          #("depth 4: position3", Arguments(game: position3, depth: 4)),
          #("depth 4: midgame_1", Arguments(game: midgame_1, depth: 4)),
        ]
        |> dict.from_list,
      ),
    ],
  )
}
