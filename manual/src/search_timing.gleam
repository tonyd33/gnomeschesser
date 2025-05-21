import bencher
import chess/game
import chess/search
import chess/search/search_state
import gleam/dict
import gleam/erlang/process
import gleam/option
import gleam/time/timestamp
import util/yielder

type Arguments {
  Arguments(game: game.Game, depth: Int)
}

pub fn main() {
  let assert Ok(starting) = game.load_fen(game.start_fen)
  let assert Ok(game2) =
    game.load_fen(
      "1nrq1rk1/3nppbp/p2pb1p1/8/2pNP3/1PN1B3/P2QBPPP/2RR2K1 w - - 0 16",
    )
  bencher.run(
    dict.from_list([
      #("search", fn(args: Arguments) {
        search_game_to_depth(args.game, args.depth)
      }),
    ]),
    [
      bencher.Warmup(2),
      bencher.Parallel(2),
      bencher.Inputs(
        dict.from_list([
          #("depth 4: starting pos", Arguments(game: starting, depth: 4)),
          #("depth 4: game2", Arguments(game: game2, depth: 4)),
        ]),
      ),
    ],
  )
}

fn search_game_to_depth(game: game.Game, depth: Int) {
  let memo = search_state.new(timestamp.system_time())
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
      search.SearchDone(_, _) -> False
      search.SearchUpdate(..) -> True
      search.SearchStateUpdate(_) -> True
    }
  })
  |> yielder.run
}
