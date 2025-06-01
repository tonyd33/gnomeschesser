import chess/actors/blake
import chess/actors/yapper
import chess/game
import chess/move
import chess/search/evaluation.{type Evaluation}
import chess/uci
import gleam/erlang
import gleam/erlang/process.{type Subject}
import gleam/float
import gleam/function
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/task
import gleam/result
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp
import util/parser as p

const name = "gnomeschesser"

const authors = "The Gnomes Team"

pub fn main() {
  let #(yapper_chan, yap_chan) = yapper.start(yapper.Info)

  let yap = process.send(yap_chan, _)
  let #(_, response_chan, info_chan) = start_blake_handler(yap)

  let blake_chan = blake.start()
  let tell_blake = process.send(blake_chan, _)

  // Get to IO handling ASAP, defer this work to another thread
  task.async(fn() {
    tell_blake(blake.Init)
    tell_blake(blake.RegisterYapper(yap_chan))
    tell_blake(blake.RegisterInfoChan(info_chan))

    process.send(
      yapper_chan,
      yapper.TransformLevel(yapper.Debug, yapper.prefix_debug()),
    )
    process.send(
      yapper_chan,
      yapper.TransformLevel(yapper.Warn, yapper.prefix_warn()),
    )
    process.send(
      yapper_chan,
      yapper.TransformLevel(yapper.Err, yapper.prefix_err()),
    )
  })

  loop(UCIState(tell_blake, yap, response_chan))
}

type UCIState {
  UCIState(
    tell_blake: fn(blake.Message) -> Nil,
    yap: fn(yapper.Yap) -> Nil,
    response_chan: Subject(blake.Response),
  )
}

fn handle_uci(s: UCIState, cmd) {
  case cmd {
    uci.EngCmdUCI -> {
      uci.GUICmdId(uci.Name(name))
      |> uci.serialize_gui_cmd
      |> yapper.info
      |> s.yap

      uci.GUICmdId(uci.Author(authors))
      |> uci.serialize_gui_cmd
      |> yapper.info
      |> s.yap

      uci.GUICmdUCIOk
      |> uci.serialize_gui_cmd
      |> yapper.info
      |> s.yap

      True
    }
    uci.EngCmdQuit -> {
      s.tell_blake(blake.Shutdown)
      False
    }
    uci.EngCmdUCINewGame -> {
      s.tell_blake(blake.NewGame)
      True
    }
    uci.EngCmdIsReady -> {
      uci.GUICmdReadyOk
      |> uci.serialize_gui_cmd
      |> yapper.info
      |> s.yap

      True
    }
    uci.EngCmdPosition(moves:, position:) -> {
      case position {
        uci.PositionStartPos -> s.tell_blake(blake.LoadFEN(game.start_fen))
        uci.PositionFEN(fen) -> s.tell_blake(blake.LoadFEN(fen))
      }

      s.tell_blake(blake.DoMoves(moves))
      True
    }
    uci.EngCmdStop -> {
      s.tell_blake(blake.Stop)
      True
    }
    uci.EngCmdGo(params:) -> {
      let now = timestamp.system_time()
      let deadline =
        params
        |> list.find_map(fn(x) {
          case x {
            uci.GoParamMoveTime(movetime) -> Ok(movetime)
            _ -> Error(Nil)
          }
        })
        |> result.map(fn(x) {
          timestamp.add(now, duration.milliseconds({ x * 95 } / 100))
        })
        |> option.from_result

      deadline
      |> option.map(timestamp.to_rfc3339(_, calendar.local_offset()))
      |> option.map(fn(x) { "deadline " <> x })
      |> option.unwrap("no deadline")
      |> yapper.debug
      |> s.yap

      let depth =
        params
        |> list.find_map(fn(x) {
          case x {
            uci.GoParamDepth(depth) -> Ok(depth)
            _ -> Error(Nil)
          }
        })
        |> option.from_result

      s.tell_blake(blake.Go(deadline:, depth:, reply_to: s.response_chan))
      True
    }
    _ -> {
      "Command recognized but ignored."
      |> yapper.warn
      |> s.yap
      True
    }
  }
}

fn loop(s: UCIState) {
  let engine_cmd = uci.engine_cmd()
  case erlang.get_line("") {
    Error(erlang.Eof) -> Nil
    Error(erlang.NoData) -> Nil
    Ok(line) -> {
      let parsed = p.run(engine_cmd, line)

      let continue = case parsed {
        Ok(cmd) -> handle_uci(s, cmd)
        Error(_) -> {
          { "Unrecognized command: " <> line }
          |> yapper.warn
          |> s.yap
          True
        }
      }

      case continue {
        True -> loop(s)
        False -> Nil
      }
    }
  }
}

type BlakeMessage {
  Response(blake.Response)
  Info(List(blake.Info))
}

fn start_blake_handler(yap) {
  let out_chan = process.new_subject()
  process.start(
    fn() {
      let chan = process.new_subject()
      let best_evaluation_chan = process.new_subject()
      let info_chan = process.new_subject()
      let selector =
        process.new_selector()
        |> process.selecting(chan, function.identity)
        |> process.selecting(best_evaluation_chan, Response)
        |> process.selecting(info_chan, Info)
      process.send(out_chan, #(chan, best_evaluation_chan, info_chan))
      loop_blake_handler(yap, selector)
    },
    True,
  )
  process.receive_forever(out_chan)
}

fn blake_info_to_uci_info(blake_info: blake.Info) -> Result(uci.UCIInfo, Nil) {
  case blake_info {
    blake.CurrMove(n) -> Ok(uci.InfoCurrMove(n))
    blake.CurrMoveNumber(n) -> Ok(uci.InfoCurrMoveNumber(n))
    blake.Depth(n) -> Ok(uci.InfoDepth(n))
    blake.HashFull(n) -> Ok(uci.InfoHashFull(n))
    blake.MultiPrincipalVariation(n) -> Ok(uci.InfoMultiPrincipalVariation(n))
    blake.Nodes(n) -> Ok(uci.InfoNodes(n))
    blake.NodesPerSecond(n) -> Ok(uci.InfoNodesPerSecond(n))
    blake.PrincipalVariation(pv) -> Ok(uci.InfoPrincipalVariation(pv))
    blake.Score(s) ->
      case s {
        blake.Centipawns(n) -> Ok(uci.InfoScore(uci.ScoreCentipawns(n)))
        blake.Mate(n) -> Ok(uci.InfoScore(uci.ScoreMate(n)))
      }
    blake.SelDepth(n) -> Ok(uci.InfoSelDepth(n))
    blake.String(s) -> Ok(uci.InfoString(s))
    blake.Time(n) -> Ok(uci.InfoTime(n))
  }
}

fn loop_blake_handler(yap, recv_selector) {
  case process.select_forever(recv_selector) {
    Response(blake.Response(game:, evaluation:)) ->
      case evaluation.best_move {
        Some(best_move) -> {
          uci.GUICmdBestMove(move: move.to_lan(best_move), ponder: None)
          |> uci.serialize_gui_cmd
          |> io.println
        }
        None -> {
          let s = {
            "Blake sent us an evaluation without a move!\n"
            <> "FEN: "
            <> game.to_fen(game)
            <> "\n"
          }

          s
          |> yapper.err
          |> yap

          panic as s
        }
      }
    Info(infos) -> {
      infos
      |> list.filter_map(blake_info_to_uci_info)
      |> uci.GUICmdInfo
      |> uci.serialize_gui_cmd
      |> io.println
    }
  }

  loop_blake_handler(yap, recv_selector)
}
