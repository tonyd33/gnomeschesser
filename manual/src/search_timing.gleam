import bencher
import chess/actors/blake
import chess/game
import chess/move
import chess/search
import chess/search/game_history
import chess/search/search_state
import gleam/dict
import gleam/erlang/process
import gleam/list
import gleam/option
import gleam/result
import gleam/time/timestamp
import gleeunit/should
import util/state
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
  let assert Ok(game3) =
    game.load_fen(
      "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
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
          #("depth 6: starting pos", Arguments(game: starting, depth: 6)),
          #("depth 6: game2", Arguments(game: game2, depth: 6)),
          #("depth 6: game3", Arguments(game: game3, depth: 6)),
        ]),
      ),
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
