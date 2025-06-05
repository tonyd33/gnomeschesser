import bencher
import chess/game
import chess/search
import chess/search/game_history
import chess/search/search_state
import gleam/dict
import gleam/option
import gleam/time/timestamp
import util/state

type Arguments {
  Arguments(game: game.Game, depth: Int)
}

pub fn main() {
  let inputs = [
    #("depth 6: starting pos", {
      let assert Ok(game) = game.load_fen(game.start_fen)
      Arguments(game:, depth: 6)
    }),
    #("depth 6: game2", {
      let assert Ok(game) =
        game.load_fen(
          "1nrq1rk1/3nppbp/p2pb1p1/8/2pNP3/1PN1B3/P2QBPPP/2RR2K1 w - - 0 16",
        )
      Arguments(game:, depth: 6)
    }),
    #("depth 6: game3", {
      let assert Ok(game) =
        game.load_fen(
          "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
        )
      Arguments(game:, depth: 6)
    }),
    #("depth 6: game4", {
      let assert Ok(game) =
        game.load_fen("8/8/8/7p/8/2b2kPp/3p1P2/4N1K1 b - - 1 63")
      Arguments(game:, depth: 6)
    }),
    #("depth 6: game5", {
      let assert Ok(game) =
        game.load_fen("r6r/1b2k1bq/8/8/7B/8/8/R3K2R b KQ - 3 2")
      Arguments(game:, depth: 6)
    }),
    #("depth 6: game6", {
      let assert Ok(game) = game.load_fen("8/8/8/2k5/2pP4/8/B7/4K3 b - d3 0 3")
      Arguments(game:, depth: 6)
    }),
    #("depth 6: game7", {
      let assert Ok(game) =
        game.load_fen(
          "r1bqkbnr/pppppppp/n7/8/8/P7/1PPPPPPP/RNBQKBNR w KQkq - 2 2",
        )
      Arguments(game:, depth: 6)
    }),
    #("depth 6: game8", {
      let assert Ok(game) =
        game.load_fen(
          "r3k2r/p1pp1pb1/bn2Qnp1/2qPN3/1p2P3/2N5/PPPBBPPP/R3K2R b KQkq - 3 2",
        )
      Arguments(game:, depth: 6)
    }),
  ]
  bencher.run(
    dict.from_list([
      #("search", fn(args: Arguments) {
        search_game_to_depth(args.game, args.depth)
      }),
    ]),
    [
      bencher.Warmup(2),
      bencher.Parallel(2),
      bencher.Inputs(dict.from_list(inputs)),
    ],
  )
}

fn search_game_to_depth(game: game.Game, depth: Int) {
  let memo = search_state.new(timestamp.system_time())
  search.checkpointed_iterative_deepening(
    game,
    1,
    search.SearchOpts(max_depth: option.Some(depth)),
    game_history.new(),
    fn(_, _, _) { Nil },
  )
  |> state.go(#(fn(_) { False }, memo))
}
