import chess/game
import chess/search
import gleam/erlang/process
import gleam/option
import gleam/time/timestamp
import glychee/benchmark
import glychee/configuration
import util/yielder

type Arguments {
  Arguments(game: game.Game, depth: Int)
}

pub fn main() {
  configuration.initialize()
  configuration.set_pair(configuration.Warmup, 2)
  configuration.set_pair(configuration.Parallel, 2)

  let assert Ok(starting) = game.load_fen(game.start_fen)
  let assert Ok(game2) =
    game.load_fen(
      "1nrq1rk1/3nppbp/p2pb1p1/8/2pNP3/1PN1B3/P2QBPPP/2RR2K1 w - - 0 16",
    )

  // Run the benchmarks
  benchmark.run(
    [
      benchmark.Function(label: "search", callable: fn(test_data: Arguments) {
        fn() { search_game_to_depth(test_data.game, test_data.depth) }
      }),
    ],
    [
      benchmark.Data(
        label: "starting",
        data: Arguments(game: starting, depth: 2),
      ),
      benchmark.Data(
        label: "some position",
        data: Arguments(game: game2, depth: 2),
      ),
    ],
  )
}

fn search_game_to_depth(game: game.Game, depth: Int) {
  let memo = search.tt_new(timestamp.system_time())
  let subject = process.new_subject()
  let _search_pid =
    search.new(
      game,
      memo,
      subject,
      search.SearchOpts(max_depth: option.Some(depth)),
    )

  yielder.repeat(subject)
  |> yielder.take_while(fn(subject) {
    case process.receive_forever(subject) {
      search.SearchDone(_, _, _) -> False
      search.SearchUpdate(_, _, _) -> True
    }
  })
  |> yielder.run
}
