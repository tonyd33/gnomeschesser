//// Donovan is a searcher thread. Donovan responds to requests to start and
//// stop a search.
////
//// Donovan structures the search in an easily-interruptable manner so that
//// he's responsive to messages.
////

import chess/game.{type Game}
import chess/search/evaluation.{type Evaluation, Evaluation}
import chess/search/search_state2.{type SearchState, SearchState}
import chess/search2
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option, None, Some}
import gleam/time/timestamp
import util/interruptable_state.{type InterruptableState} as interruptable
import util/state.{type State, State}

pub opaque type Donovan {
  Donovan(search_state: SearchState)
}

pub type Message {
  Go(game: Game, reply_with: Subject(Result(Evaluation, Nil)))
  /// Stop the search immediately.
  Stop
  Shutdown
}

pub fn start() {
  let out_chan = process.new_subject()
  process.start(
    fn() {
      let chan = process.new_subject()
      process.send(out_chan, chan)
      loop(new(), chan)
    },
    True,
  )
  process.receive_forever(out_chan)
}

fn new() {
  Donovan(search_state: search_state2.new(timestamp.system_time()))
}

fn loop(donovan: Donovan, recv_chan: Subject(Message)) -> Nil {
  let r = case process.receive_forever(recv_chan) {
    Go(game, send_chan) -> {
      let interrupt = fn() {
        case process.receive(recv_chan, 0) {
          Ok(Stop) -> True
          _ -> False
        }
      }

      let #(evaluation, new_state) =
        {
          let now = timestamp.system_time()
          use <- state.discard({
            use search_state <- state.modify
            SearchState(..search_state, interrupt:)
          })
          use <- state.discard(search_state2.stats_zero(now))

          search2.search_loop(
            game,
            1,
            search2.SearchOpts(max_depth: None),
            dict.new(),
          )
        }
        |> state.go(donovan.search_state)

      process.send(send_chan, evaluation)

      Ok(Donovan(..donovan, search_state: new_state))
    }
    Stop -> Ok(donovan)
    Shutdown -> Error(Nil)
  }

  case r {
    Ok(donovan) -> loop(donovan, recv_chan)
    Error(Nil) -> Nil
  }
}
