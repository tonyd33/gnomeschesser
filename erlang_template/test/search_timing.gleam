import chess/game
import chess/move
import chess/search
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/io
import gleam/option
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import util/yielder

pub fn main() {
  search_fen_to_depth(
    "1nrq1rk1/3nppbp/p2pb1p1/8/2pNP3/1PN1B3/P2QBPPP/2RR2K1 w - - 0 16",
    2,
  )
  search_fen_to_depth(game.start_fen, 5)
}

fn search_fen_to_depth(fen: String, depth: Int) {
  let assert Ok(game) = game.load_fen(fen)

  let memo = search.tt_new(timestamp.system_time())
  let subject = process.new_subject()
  let start_time = timestamp.system_time()
  let search_pid =
    search.new(
      game,
      memo,
      subject,
      search.SearchOpts(max_depth: option.Some(2)),
    )

  io.println_error("Searching through: " <> fen)
  yielder.repeat(subject)
  |> yielder.take_while(fn(subject) {
    case process.receive_forever(subject) {
      search.SearchDone(best_evaluation:, game: _, transposition: _) -> {
        let end_time = timestamp.system_time()

        io.println_error(
          "Got best move at depth "
          <> int.to_string(depth)
          <> " in: "
          <> {
            timestamp.difference(start_time, end_time)
            |> duration.to_seconds
            |> float.to_string
          }
          <> " seconds",
        )

        best_evaluation.best_move
        |> option.map(move.to_lan)
        |> string.inspect
        |> io.println_error

        False
      }
      search.SearchUpdate(_, _, _) -> True
    }
  })
  |> yielder.run
  process.unlink(search_pid)
  process.kill(search_pid)
}
