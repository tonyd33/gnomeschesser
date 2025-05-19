import bencher
import chess/game
import chess/util/perft
import gleam/dict

type Arguments {
  Arguments(game: game.Game, depth: Int)
}

pub fn main() {
  // let assert Ok(game) =
  //   game.load_fen(
  //     "rnb1kb1r/pp3ppp/2ppp3/4P1N1/3P4/3B1P2/PPP4P/RN1QK2n b Qkq - 1 10",
  //   )
  // perft.perft(game, 4)

  // let assert 4_865_609 = perft.perft(starting, 5)
  // let assert 4_085_603 = perft.perft(kiwipete, 4)
  let assert Ok(starting) = game.load_fen(game.start_fen)
  let assert Ok(kiwipete) =
    game.load_fen(
      "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
    )
  let assert Ok(midgame_1) =
    game.load_fen(
      "rnb1kb1r/pp3ppp/2ppp3/4P1N1/3P4/3B1P2/PPP4P/RN1QK2n b Qkq - 1 10",
    )
  bencher.run(
    dict.from_list([
      #("perft", fn(args: Arguments) { perft.perft(args.game, args.depth) }),
    ]),
    [
      bencher.Warmup(2),
      bencher.Parallel(2),
      bencher.Time(20),
      bencher.Inputs(
        dict.from_list([
          #("depth 4: starting pos", Arguments(game: starting, depth: 4)),
          #("depth 3: kiwipete", Arguments(game: kiwipete, depth: 4)),
          #("depth 4: midgame_1", Arguments(game: midgame_1, depth: 4)),
        ]),
      ),
    ],
  )
}
