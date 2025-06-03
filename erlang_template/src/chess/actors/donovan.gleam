//// Donovan is a searcher thread. Donovan responds to requests to start and
//// stop a search.
////
//// Donovan structures the search in an easily-interruptable manner so that
//// he's responsive to messages.
////
//// Donovan is extremely dumb though, only exposing a very basic interface to
//// stop and start searches and executes his controller's callbacks. Even
//// information flow out of this thread is dictated by the controller's
//// callbacks.
////

import chess/game.{type Game}
import chess/search
import chess/search/evaluation.{type Evaluation, Evaluation}
import chess/search/search_state.{
  type SearchState, type SearchStats, SearchState,
}
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import util/dict_addons
import util/interruptable_state as interruptable
import util/state

type Donovan =
  SearchState

pub type Message {
  Clear
  Go(
    game: Game,
    history: List(Game),
    depth: Option(Int),
    stats_start_time: Option(Timestamp),
    // Callback to be executed *in Donovan's thread* when a checkpoint is
    // made (when an iteration of deepening is complete).
    on_checkpoint: fn(SearchStats, evaluation.Depth, Evaluation) -> Nil,
    // Callback to be executed *in Donovan's thread* when the search has
    // terminated for whatever reason.
    on_done: fn(SearchStats, Game, Result(Evaluation, Nil)) -> Nil,
  )
  Stop
  Die
}

pub fn start() {
  let out_chan = process.new_subject()
  process.start(
    fn() {
      let chan = process.new_subject()
      process.send(out_chan, chan)
      loop(new(), chan)
    },
    False,
  )
  process.receive_forever(out_chan)
}

fn new() {
  search_state.new(timestamp.system_time())
}

fn loop(donovan: Donovan, recv_chan: Subject(Message)) -> Nil {
  let r = case process.receive_forever(recv_chan) {
    Clear -> Ok(new())
    Go(game, history, depth, stats_start_time, on_checkpoint, on_done) -> {
      let interrupt = fn(_) {
        case process.receive(recv_chan, 0) {
          Ok(Stop) -> True
          Ok(Die) -> {
            // If we get this command in the search loop, exiting the search
            // loop isn't sufficient. Donovan needs to completely die.
            process.kill(process.self())
            True
          }
          _ -> False
        }
      }

      let #(evaluation, #(_, new_donovan)) =
        {
          let now = option.unwrap(stats_start_time, timestamp.system_time())
          use <- interruptable.discard(
            interruptable.from_state(search_state.stats_zero(now)),
          )

          search.checkpointed_iterative_deepening(
            game,
            1,
            search.SearchOpts(max_depth: depth),
            history |> dict_addons.zip_dict_by(game.hash),
            on_checkpoint,
          )
        }
        |> state.go(#(interrupt, donovan))

      on_done(new_donovan.stats, game, evaluation)

      Ok(new_donovan)
    }
    Stop -> Ok(donovan)
    Die -> Error(Nil)
  }

  case r {
    Ok(donovan) -> loop(donovan, recv_chan)
    Error(Nil) -> Nil
  }
}
