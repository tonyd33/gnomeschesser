//// Blake is the shell surround the core of our engine. Control of the engine is
//// governed through managing Blake.
////

import chess/actors/donovan
import chess/actors/yapper
import chess/game.{type Game}
import chess/move
import chess/player
import chess/search/evaluation.{type Evaluation, Evaluation, PV}
import chess/search/search_state.{type SearchStats}
import chess/tablebase.{type Tablebase}
import gleam/bool
import gleam/erlang/process.{type Subject, type Timer}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/task
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam/time/duration
import gleam/time/timestamp.{type Timestamp}
import util/xint

pub type Score {
  Centipawns(n: Int)
  Mate(n: Int)
}

pub type Info {
  Depth(depth: Int)
  SelDepth(depth: Int)
  Time(time: Int)
  Nodes(nodes: Int)
  PrincipalVariation(moves: List(String))
  MultiPrincipalVariation(n: Int)
  Score(score: Score)
  CurrMove(move: String)
  CurrMoveNumber(n: Int)
  HashFull(n: Int)
  NodesPerSecond(n: Int)
  String(s: String)
}

pub type Response {
  Response(game: Game, evaluation: Evaluation)
}

type Nonce =
  #(Int, Int)

type Blake {
  Blake(
    game: Game,
    history: List(Game),
    tablebase: Tablebase,
    donovan_chan: Subject(donovan.Message),
    yap_chan: Option(Subject(yapper.Yap)),
    info_chan: Option(Subject(List(Info))),
    nonces: Set(Nonce),
    stop_timer: Option(Timer),
  )
}

pub type Message {
  Init
  NewGame

  RegisterYapper(yap_chan: Subject(yapper.Yap))
  RegisterInfoChan(info_chan: Subject(List(Info)))

  Load(game: Game)
  LoadFEN(fen: String)

  DoMoves(moves: List(String))
  AppendHistory(game: Game, validation: HistoryValidation)
  AppendHistoryFEN(fen: String, validation: HistoryValidation)

  Go(
    deadline: Option(Timestamp),
    depth: Option(Int),
    stats_start_time: Option(Timestamp),
    reply_to: Subject(Response),
  )
  Think

  Stop
  Shutdown

  // For internal use. See documentation in the implemention of Go for
  // an explanation.
  AtomicNonceUse(Nonce, f: fn() -> Nil)
  NonceCheck(Nonce, f: fn() -> Nil)
}

pub type HistoryValidation {
  Smart
  Dumb
  HalfmoveClock
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
  let assert Ok(game) = game.load_fen(game.start_fen)
  Blake(
    game:,
    history: [],
    tablebase: tablebase.empty(),
    donovan_chan: donovan.start(),
    yap_chan: None,
    info_chan: None,
    nonces: set.new(),
    stop_timer: None,
  )
}

fn yap(blake: Blake, m: yapper.Yap) {
  case blake.yap_chan {
    None -> Nil
    Some(yap_chan) -> process.send(yap_chan, m)
  }
}

fn loop(blake: Blake, recv_chan: Subject(Message)) {
  // TODO: To really fortify this model even more, we would save the
  // checkpoints from Donovan and send them as a backup if we don't get
  // a response fast enough somehow

  let r = case process.receive_forever(recv_chan) {
    Init -> Ok(Blake(..blake, tablebase: tablebase.load()))
    NewGame -> {
      case blake.stop_timer {
        Some(stop_timer) -> {
          process.cancel_timer(stop_timer)
          Nil
        }
        None -> Nil
      }
      // I don't really know why but if I Clear Donovan instead of killing him,
      // subsequent searches seem slow and time out...? At least, this seems to
      // be the case.
      let donovan_pid = process.subject_owner(blake.donovan_chan)
      process.send(blake.donovan_chan, donovan.Die)
      // Make sure donovan is really dead
      process.kill(donovan_pid)

      let assert Ok(game) = game.load_fen(game.start_fen)
      Ok(
        Blake(
          ..blake,
          game:,
          history: [],
          donovan_chan: donovan.start(),
          nonces: set.new(),
          stop_timer: None,
        ),
      )
    }
    Load(game) -> Ok(Blake(..blake, game:, history: []))
    LoadFEN(fen) -> {
      let game = game.load_fen(fen)

      case game {
        Ok(game) -> Ok(Blake(..blake, game:, history: []))
        Error(Nil) -> {
          yapper.warn("Received bad FEN: " <> fen)
          |> yap(blake, _)

          Ok(blake)
        }
      }
    }
    DoMoves(moves) -> {
      let res = {
        use ht, lan <- list.fold(moves, Ok(#(blake.game, blake.history)))
        use #(head, tail) <- result.try(ht)

        use move <- result.try(game.validate_move(move.from_lan(lan), head))
        let head1 = game.apply(head, move)
        Ok(#(head1, [head, ..tail]))
      }

      case res {
        Ok(#(game, history)) -> Ok(Blake(..blake, game:, history:))
        Error(Nil) -> {
          { "Received bad moves: " <> string.join(moves, ", ") }
          |> yapper.warn
          |> yap(blake, _)

          Ok(blake)
        }
      }
    }
    AppendHistory(game:, validation:) -> {
      case validation {
        Smart -> Ok(smart_append_history(blake, game))
        Dumb -> Ok(dumb_append_history(blake, game))
        HalfmoveClock -> Ok(halfmove_clock_append_history(blake, game))
      }
    }
    AppendHistoryFEN(fen:, validation:) -> {
      case game.load_fen(fen) {
        Ok(game) ->
          case validation {
            Smart -> Ok(smart_append_history(blake, game))
            Dumb -> Ok(dumb_append_history(blake, game))
            HalfmoveClock -> Ok(halfmove_clock_append_history(blake, game))
          }
        Error(Nil) -> {
          yapper.warn("Failed to load FEN: " <> fen)
          |> yap(blake, _)
          Ok(blake)
        }
      }
    }
    RegisterYapper(yap_chan) -> Ok(Blake(..blake, yap_chan: Some(yap_chan)))
    RegisterInfoChan(info_chan) ->
      Ok(Blake(..blake, info_chan: Some(info_chan)))
    Go(deadline, depth, stats_start_time, client) -> {
      // Goal:
      // - Reset Donovan to a sane state
      //   - Donovan should be not be searching
      //   - There should be no pending timers to stop Donovan
      // - Queue a task to look up a move from tablebase
      // - Start the search to find a move
      // - Whichever one finishes first should send a response to client
      //
      // This is achieved by the following:
      // - Create a nonce
      // - For either task, right before sending, it will check if the nonce
      //   has already been used and only send to the client if it hasn't.
      // - Checking the nonce atomically marks the nonce as having been
      //   used.

      // Reset Donovan to a sane state:
      {
        // Stop any pending timers, if any
        case blake.stop_timer {
          Some(stop_timer) -> {
            process.cancel_timer(stop_timer)
            Nil
          }
          None -> Nil
        }
        // Make sure Donovan is not running
        process.send(blake.donovan_chan, donovan.Stop)
      }

      // If movetime is set, set a new timer to stop after movetime.
      let stop_timer = {
        use deadline <- option.map(deadline)
        let movetime = {
          let now = timestamp.system_time()
          let duration = timestamp.difference(now, deadline)
          let #(s, ns) = duration.to_seconds_and_nanoseconds(duration)
          { s * 1000 } + { ns / 1_000_000 }
        }
        process.send_after(blake.donovan_chan, movetime, donovan.Stop)
      }

      // This should be called after we found a move and cleans up any pending
      // timers and stops Donovan.
      let cleanup_donovan = fn() {
        case stop_timer {
          Some(stop_timer) -> {
            process.cancel_timer(stop_timer)
            Nil
          }
          None -> Nil
        }
        process.send(blake.donovan_chan, donovan.Stop)
      }

      let nonce =
        timestamp.system_time() |> timestamp.to_unix_seconds_and_nanoseconds

      // `once` takes a callback and executes it only if the nonce wasn't
      // already used and uses the nonce.
      let once = fn(f: fn() -> Nil) {
        process.send(recv_chan, AtomicNonceUse(nonce, f))
      }

      // `if_nonce_free` is like `once`, but doesn't use the nonce.
      let if_nonce_free = fn(f: fn() -> Nil) {
        process.send(recv_chan, NonceCheck(nonce, f))
      }

      // This will queue a task in the background to look in the tablebase and
      // send a move, racing against the search.
      task.async(fn() {
        use move <- result.try(tablebase.query(blake.tablebase, blake.game))
        let response =
          Response(
            blake.game,
            Evaluation(
              score: xint.from_int(0),
              best_move: Some(move),
              node_type: PV,
            ),
          )
        {
          use <- once
          process.send(client, response)
          cleanup_donovan()
        }

        Ok(Nil)
      })

      // Called every iteration of iterative deepening.
      // Sends info.
      let on_checkpoint = fn(
        stats: SearchStats,
        current_depth,
        best_evaluation: Evaluation,
      ) {
        let now = timestamp.system_time()

        let stats_str = search_state.stats_to_string(stats, now)
        yapper.debug(stats_str) |> yap(blake, _)

        let search_info =
          aggregate_search_info(now, stats, current_depth, best_evaluation)

        case blake.info_chan {
          Some(info_chan) -> {
            use <- if_nonce_free
            process.send(info_chan, search_info)
          }
          None -> Nil
        }

        Nil
      }

      // Called when search is done. Races against tablebase query to send
      // a move.
      let on_done = fn(
        stats: SearchStats,
        game,
        evaluation: Result(Evaluation, Nil),
      ) {
        {
          let now = timestamp.system_time()
          let dt =
            timestamp.difference(stats.init_time, now)
            |> duration.to_seconds
            |> float.multiply(1000.0)
            |> float.round
            |> int.max(1)
            |> int.to_string

          yapper.debug("Search took " <> dt <> "ms")
          |> yap(blake, _)
        }
        use <- once
        let evaluation = case evaluation {
          Ok(Evaluation(best_move: None, ..)) | Error(Nil) -> {
            yapper.warn(
              "We got no evaluation or best move through searching, for FEN: "
              <> game.to_fen(game)
              <> ". Search will fall back to a random move.",
            )
            |> yap(blake, _)

            // If we somehow still failed to get a move, fall back to a random
            // move.
            let random_move =
              game.valid_moves(blake.game)
              |> list.shuffle
              |> list.first
              |> option.from_result
            Evaluation(
              score: xint.from_int(0),
              best_move: random_move,
              node_type: PV,
            )
          }
          Ok(evaluation) -> evaluation
        }
        process.send(client, Response(game, evaluation))
        cleanup_donovan()
      }

      yapper.debug("Asking donovan to work.")
      |> yap(blake, _)

      process.send(
        blake.donovan_chan,
        donovan.Go(
          game: blake.game,
          history: blake.history,
          depth:,
          stats_start_time:,
          on_checkpoint:,
          on_done:,
        ),
      )
      Ok(Blake(..blake, stop_timer:))
    }
    Think -> {
      // Stop any timers that may potentially disrupt thinking.
      case blake.stop_timer {
        Some(stop_timer) -> {
          process.cancel_timer(stop_timer)
          Nil
        }
        None -> Nil
      }
      // Stop active search, if any.
      process.send(blake.donovan_chan, donovan.Stop)

      let on_checkpoint = fn(stats: SearchStats, _, _) {
        let now = timestamp.system_time()

        let stats = search_state.stats_to_string(stats, now)
        stats |> yapper.debug |> yap(blake, _)
      }

      let on_done = fn(stats: SearchStats, _, _) {
        let now = timestamp.system_time()
        let dt =
          search_state.stats_delta_time_ms(stats, now)
          |> int.max(1)
          |> int.to_string
        yapper.debug("Search took " <> dt <> "ms")
        |> yap(blake, _)
      }

      yapper.debug("Asking donovan to think.")
      |> yap(blake, _)

      process.send(
        blake.donovan_chan,
        donovan.Go(
          game: blake.game,
          history: blake.history,
          depth: None,
          stats_start_time: None,
          on_checkpoint:,
          on_done:,
        ),
      )
      Ok(Blake(..blake, stop_timer: None))
    }
    Stop -> {
      process.send(blake.donovan_chan, donovan.Stop)
      Ok(blake)
    }
    Shutdown -> {
      process.send(blake.donovan_chan, donovan.Die)
      Error(Nil)
    }
    AtomicNonceUse(nonce, f) -> {
      case set.contains(blake.nonces, nonce) {
        True -> Nil
        False -> f()
      }
      Ok(Blake(..blake, nonces: set.insert(blake.nonces, nonce)))
    }
    NonceCheck(nonce, f) -> {
      case set.contains(blake.nonces, nonce) {
        True -> Nil
        False -> f()
      }
      Ok(blake)
    }
  }

  case r {
    Ok(blake) -> loop(blake, recv_chan)
    _ -> Nil
  }
}

fn aggregate_search_info(
  now,
  stats: SearchStats,
  current_depth,
  best_evaluation: Evaluation,
) {
  let dt = search_state.stats_delta_time_ms(stats, now) |> int.max(1)
  let nps =
    search_state.stats_nodes_per_second(stats, now) |> float.round |> int.max(1)
  let nodes_searched = stats.nodes_searched |> int.max(1)
  let hashfull = search_state.stats_hashfull(stats)

  let score = case best_evaluation.score {
    xint.Finite(score) -> Centipawns(score)
    _ -> Mate(xint.sign(best_evaluation.score))
  }

  [
    Depth(current_depth),
    Score(score),
    Nodes(nodes_searched),
    Time(dt),
    NodesPerSecond(nps),
    HashFull(hashfull),
    PrincipalVariation(
      best_evaluation.best_move
      |> option.map(list.wrap)
      |> option.unwrap([])
      |> list.map(move.to_lan),
    ),
  ]
}

/// Modify the history in a slightly smart manner:
/// - Don't append to history unless actually necessary
/// - If coherence conditions fail, the history is flushed.
///
fn smart_append_history(blake: Blake, game) {
  let new_hash = game.hash(game)
  let old_hash = game.hash(blake.game)

  // Return early if it's the same game. Nothing needs to change.
  use <- bool.guard(new_hash == old_hash, blake)

  // Otherwise check coherence conditions and reset the history if necessary.
  let new_fmn = game.fullmove_number(game)
  let old_fmn = game.fullmove_number(blake.game)

  let new_turn = game.turn(game)
  let old_turn = game.turn(blake.game)

  let append =
    {
      new_fmn == old_fmn + 1
      && new_turn == player.White
      && old_turn == player.Black
    }
    || {
      new_fmn == old_fmn && new_turn == player.Black && old_turn == player.White
    }
  // let reset = !append

  case append {
    True -> Blake(..blake, game:, history: [blake.game, ..blake.history])
    False -> {
      // Log that we have to flush the history if coherence conditions failed.
      case blake.history {
        [_, ..] -> {
          yapper.warn(
            "Coherence conditions were not met. History must be flushed",
          )
          |> yap(blake, _)
        }
        // Unless there was no history to begin with. Then, it was likely
        // expected that coherence conditions were not met.
        [] -> Nil
      }

      Blake(..blake, game:, history: [])
    }
  }
}

fn dumb_append_history(blake: Blake, game) {
  Blake(..blake, game:, history: [blake.game, ..blake.history])
}

fn halfmove_clock_append_history(blake: Blake, game) {
  let flush = game.halfmove_clock(game) == 0
  case flush {
    True -> Blake(..blake, game:, history: [])
    False -> Blake(..blake, game:, history: [blake.game, ..blake.history])
  }
}
