//// Blake is the shell surround the core of our engine. Control of the engine is
//// governed through managing Blake.
////

import chess/actors/donovan
import chess/actors/yapper
import chess/game.{type Game}
import chess/move
import chess/search/evaluation.{type Evaluation}
import chess/search/search_state.{type SearchState, SearchState}
import gleam/bool
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/result
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

type Blake {
  Blake(
    game: Game,
    history: List(Game),
    donovan_chan: Subject(donovan.Message),
    yap_chan: Option(Subject(yapper.Yap)),
    info_chan: Option(Subject(List(Info))),
  )
}

pub type Message {
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
}

pub fn start() {
  let assert Ok(blake) = actor.start(new(), handle_message)
  blake
}

fn new() {
  let assert Ok(game) = game.load_fen(game.start_fen)
  Blake(
    game:,
    history: [],
    donovan_chan: donovan.start(),
    yap_chan: None,
    info_chan: None,
  )
}

fn yap(blake: Blake, m: yapper.Yap) {
  case blake.yap_chan {
    None -> Nil
    Some(yap_chan) -> process.send(yap_chan, m)
  }
}

fn handle_message(message: Message, blake: Blake) -> actor.Next(Message, Blake) {
  case message {
    NewGame -> {
      process.send(blake.donovan_chan, donovan.Stop)
      let assert Ok(game) = game.load_fen(game.start_fen)
      actor.continue(Blake(..blake, game:, history: []))
    }
    RequestHistory(client) -> {
      process.send(client, blake.history)
      actor.continue(blake)
    }
    Load(game) -> actor.continue(Blake(..blake, game:, history: []))
    LoadFEN(fen) -> {
      let game = game.load_fen(fen)

      case game {
        Ok(game) -> actor.continue(Blake(..blake, game:, history: []))
        Error(Nil) -> {
          { "Received bad FEN: " <> fen }
          |> yapper.warn
          |> yap(blake, _)

          actor.continue(blake)
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
        Ok(#(game, history)) -> actor.continue(Blake(..blake, game:, history:))
        Error(Nil) -> {
          { "Received bad moves: " <> string.join(moves, ", ") }
          |> yapper.warn
          |> yap(blake, _)

          actor.continue(blake)
        }
      }
    }
    AppendHistory(game:) -> {
      actor.continue(smart_append_history(blake, game))
    }
    AppendHistoryFEN(fen:) -> {
      case game.load_fen(fen) {
        Ok(game) -> actor.continue(smart_append_history(blake, game))

        Error(Nil) -> {
          { "Failed to load FEN: " <> fen }
          |> yapper.warn
          |> yap(blake, _)
          actor.continue(blake)
        }
      }
    }
    RegisterYapper(yap_chan) ->
      actor.continue(Blake(..blake, yap_chan: Some(yap_chan)))
    RegisterInfoChan(info_chan) ->
      actor.continue(Blake(..blake, info_chan: Some(info_chan)))
    Go(movetime, depth, client) -> {
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
      actor.continue(blake)
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
      actor.continue(blake)
    }
    Stop -> {
      process.send(blake.donovan_chan, donovan.Stop)
      actor.continue(blake)
    }
    Shutdown -> {
      process.send(blake.donovan_chan, donovan.Die)
      actor.Stop(process.Normal)
    }
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
