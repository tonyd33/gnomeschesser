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
import chess/search/search_state.{type SearchState, SearchState}
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/timestamp
import util/dict_addons
import util/interruptable_state as interruptable
import util/state
import util/xint

pub opaque type Donovan {
  Donovan(search_state: SearchState)
}

pub type Message {
  Go(
    game: Game,
    history: List(Game),
    movetime: Option(Int),
    depth: Option(Int),
    // Callback to be executed *in Donovan's thread* when a checkpoint is
    // made (when an iteration of deepening is complete).
    on_checkpoint: fn(SearchState, evaluation.Depth, Evaluation) -> Nil,
    // Callback to be executed *in Donovan's thread* when the search has
    // terminated for whatever reason.
    on_done: fn(SearchState, Game, Evaluation) -> Nil,
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
    True,
  )
  process.receive_forever(out_chan)
}

fn new() {
  Donovan(search_state: search_state.new(timestamp.system_time()))
}

fn loop(donovan: Donovan, recv_chan: Subject(Message)) -> Nil {
  let r = case process.receive_forever(recv_chan) {
    Go(game, history, movetime, depth, on_checkpoint, on_done) -> {
      let interrupt = fn(_) {
        case process.receive(recv_chan, 0) {
          Ok(Stop) -> True
          _ -> False
        }
      }

      // If movetime is set, set a timer to stop after movetime.
      // Consider doing this timer on Blake if this is somehow unreliable
      // on the searcher thread.
      // TODO: Consider using deadlines instead and calculating time more
      // accurately.
      case movetime {
        Some(movetime) -> {
          process.send_after(recv_chan, { movetime * 95 } / 100, Stop)
          Nil
        }
        None -> Nil
      }

      let #(evaluation, #(_, new_state)) =
        {
          let now = timestamp.system_time()
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
        |> state.go(#(interrupt, donovan.search_state))

      let evaluation =
        result.unwrap(
          evaluation,
          Evaluation(xint.NegInf, evaluation.PV, None, []),
        )
      on_done(new_state, game, evaluation)

      Ok(Donovan(search_state: new_state))
    }
    Stop -> Ok(donovan)
    Die -> Error(Nil)
  }

  case r {
    Ok(donovan) -> loop(donovan, recv_chan)
    Error(Nil) -> Nil
  }
}
