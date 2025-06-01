//// Blake is the shell surround the core of our engine. Control of the engine is
//// governed through managing Blake.
////

import chess/actors/donovan
import chess/actors/yapper
import chess/game.{type Game}
import chess/move
import chess/search/evaluation.{type Evaluation, Evaluation, PV}
import chess/search/search_state.{type SearchState, SearchState}
import chess/tablebase.{type Tablebase}
import gleam/bool
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/otp/task
import gleam/result
import gleam/set.{type Set}
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
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
  )
}

pub type Message {
  Init

  RegisterYapper(yap_chan: Subject(yapper.Yap))
  RegisterInfoChan(info_chan: Subject(List(Info)))

  RequestHistory(reply_to: Subject(List(Game)))

  NewGame

  Load(game: Game)
  LoadFEN(fen: String)

  DoMoves(moves: List(String))
  AppendHistory(game: Game)
  AppendHistoryFEN(fen: String)

  Go(movetime: Option(Int), depth: Option(Int), reply_to: Subject(Response))
  Think

  Stop
  Shutdown

  // For Internal use. See documentation in the implemention of Go for
  // an explanation.
  AtomicNonceSet(Nonce, reply_to: Subject(Bool))
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
  )
}

fn yap(blake: Blake, m: yapper.Yap) {
  case blake.yap_chan {
    None -> Nil
    Some(yap_chan) -> process.send(yap_chan, m)
  }
}

fn loop(blake: Blake, recv_chan: Subject(Message)) {
  let r = case process.receive_forever(recv_chan) {
    Init -> Ok(Blake(..blake, tablebase: tablebase.load()))
    NewGame -> {
      process.send(blake.donovan_chan, donovan.Stop)
      let assert Ok(game) = game.load_fen(game.start_fen)
      Ok(Blake(..blake, game:, history: []))
    }
    RequestHistory(client) -> {
      process.send(client, blake.history)
      Ok(blake)
    }
    Load(game) -> Ok(Blake(..blake, game:, history: []))
    LoadFEN(fen) -> {
      let game = game.load_fen(fen)

      case game {
        Ok(game) -> Ok(Blake(..blake, game:, history: []))
        Error(Nil) -> {
          { "Received bad FEN: " <> fen }
          |> yapper.warn
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
    AppendHistory(game:) -> {
      Ok(smart_append_history(blake, game))
    }
    AppendHistoryFEN(fen:) -> {
      case game.load_fen(fen) {
        Ok(game) -> Ok(smart_append_history(blake, game))

        Error(Nil) -> {
          { "Failed to load FEN: " <> fen }
          |> yapper.warn
          |> yap(blake, _)
          Ok(blake)
        }
      }
    }
    RegisterYapper(yap_chan) -> Ok(Blake(..blake, yap_chan: Some(yap_chan)))
    RegisterInfoChan(info_chan) ->
      Ok(Blake(..blake, info_chan: Some(info_chan)))
    Go(movetime, depth, client) -> {
      // Goal:
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
      let nonce =
        timestamp.system_time() |> timestamp.to_unix_seconds_and_nanoseconds

      let once = fn(f: fn() -> Nil) {
        let sent = process.call_forever(recv_chan, AtomicNonceSet(nonce, _))
        case sent {
          True -> Nil
          False -> f()
        }
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
              best_line: [],
            ),
          )
        {
          use <- once
          process.send(client, response)
        }

        Ok(Nil)
      })

      let on_checkpoint = fn(
        search_state: SearchState,
        current_depth,
        best_evaluation: Evaluation,
      ) {
        let now = timestamp.system_time()

        {
          let stats = search_state.stats_to_string(search_state, now)
          stats |> yapper.debug |> yap(blake, _)
        }

        {
          case blake.info_chan {
            Some(info_chan) ->
              aggregate_search_info(
                now,
                search_state,
                current_depth,
                best_evaluation,
              )
              |> process.send(info_chan, _)
            None -> Nil
          }
        }
        Nil
      }

      let on_done = fn(s: SearchState, g, e) {
        {
          let now = timestamp.system_time()
          let dt =
            timestamp.difference(s.stats.init_time, now)
            |> duration.to_seconds
            |> float.multiply(1000.0)
            |> float.round
            |> int.max(1)
            |> int.to_string
          { "Search took " <> dt <> "ms" }
          |> yapper.debug
          |> yap(blake, _)
        }

        use <- once
        process.send(client, Response(g, e))
      }

      { "Asking donovan to work." }
      |> yapper.debug
      |> yap(blake, _)
      process.send(
        blake.donovan_chan,
        donovan.Go(
          blake.game,
          blake.history,
          movetime,
          depth,
          on_checkpoint,
          on_done,
        ),
      )
      Ok(blake)
    }
    Think -> {
      let on_checkpoint = fn(search_state: SearchState, _, _) {
        let now = timestamp.system_time()

        let stats = search_state.stats_to_string(search_state, now)
        stats |> yapper.debug |> yap(blake, _)
      }

      let on_done = fn(search_state: SearchState, _, _) {
        let now = timestamp.system_time()
        let dt =
          timestamp.difference(search_state.stats.init_time, now)
          |> duration.to_seconds
          |> float.multiply(1000.0)
          |> float.round
          |> int.max(1)
          |> int.to_string
        { "Search took " <> dt <> "ms" }
        |> yapper.debug
        |> yap(blake, _)
      }

      { "Asking donovan to think." }
      |> yapper.debug
      |> yap(blake, _)
      process.send(
        blake.donovan_chan,
        donovan.Go(
          game: blake.game,
          history: blake.history,
          movetime: None,
          depth: None,
          on_checkpoint:,
          on_done:,
        ),
      )
      Ok(blake)
    }
    Stop -> {
      process.send(blake.donovan_chan, donovan.Stop)
      Ok(blake)
    }
    Shutdown -> {
      process.send(blake.donovan_chan, donovan.Die)
      Error(Nil)
    }
    AtomicNonceSet(nonce, client) -> {
      process.send(client, set.contains(blake.nonces, nonce))
      Ok(Blake(..blake, nonces: set.insert(blake.nonces, nonce)))
    }
  }

  case r {
    Ok(blake) -> loop(blake, recv_chan)
    _ -> Nil
  }
}

fn aggregate_search_info(
  now,
  search_state: SearchState,
  current_depth,
  best_evaluation: Evaluation,
) {
  let dt =
    timestamp.difference(search_state.stats.init_time, now)
    |> duration.to_seconds
    |> float.multiply(1000.0)
    |> float.round
    |> int.max(1)
  let nps =
    search_state.stats_nodes_per_second(search_state, now)
    |> float.round
  let nodes_searched = search_state.stats.nodes_searched
  // TODO: Calculate this properly
  let hashfull = dict.size(search_state.transposition) * 1000 / 100_000

  let score = case best_evaluation.score {
    xint.Finite(score) -> Centipawns(score)
    _ ->
      Mate(
        xint.sign(best_evaluation.score)
        * list.length(best_evaluation.best_line),
      )
  }

  [
    Depth(current_depth),
    Score(score),
    Nodes(nodes_searched),
    Time(dt),
    NodesPerSecond(nps),
    HashFull(hashfull),
    PrincipalVariation(list.map(best_evaluation.best_line, move.to_lan)),
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
  let old_turn = game.turn(game)

  let append = { new_fmn - old_fmn <= 1 } && new_turn != old_turn
  // let reset = !append

  case append {
    True -> Blake(..blake, game:, history: [blake.game, ..blake.history])
    False -> {
      // Log that we have to flush the history if coherence conditions failed.
      case blake.history {
        [_, ..] -> {
          "Coherence conditions were not met. History must be flushed"
          |> yapper.warn
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
