import chess/actors/blake
import chess/actors/yapper
import chess/game
import chess/move
import chess/player
import chess/search/evaluation.{Evaluation}
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/json
import gleam/option.{type Option, None, Some}
import mist
import wisp.{type Request, type Response}
import wisp/wisp_mist

type Robot {
  Robot(
    blake_chan: Subject(blake.Message),
    yapper_chan: Subject(yapper.Message),
  )
}

pub fn start_robot() -> Nil {
  let #(yapper_chan, yap_chan) = yapper.start(yapper.Info)
  let blake_chan = blake.start()
  process.send(blake_chan, blake.RegisterYapper(yap_chan))
  process.send(blake_chan, blake.Think)

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

  let robot = Robot(blake_chan, yapper_chan)

  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    handle_request(_, robot)
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(8000)
    |> mist.start_http

  Nil
}

fn handle_request(request: Request, robot) -> Response {
  case wisp.path_segments(request) {
    ["move"] -> handle_move(request, robot)
    ["setverbosity"] -> set_verbosity(request, robot)
    _ -> wisp.ok()
  }
}

type MoveRequest {
  MoveRequest(fen: String, turn: player.Player, failed_moves: List(game.SAN))
}

fn move_decoder() -> decode.Decoder(MoveRequest) {
  use fen <- decode.field("fen", decode.string)
  use turn <- decode.field("turn", player.player_decoder())
  use failed_moves <- decode.field("failed_moves", decode.list(decode.string))
  decode.success(MoveRequest(fen:, turn:, failed_moves:))
}

fn handle_move(request: Request, robot: Robot) -> Response {
  let Robot(blake_chan:, ..) = robot
  use body <- wisp.require_string_body(request)
  case json.parse(body, move_decoder()) {
    Error(_) -> wisp.bad_request()
    // FIXME: Handle failed moves?
    Ok(MoveRequest(fen:, turn: _, failed_moves: _)) -> {
      // Stop any currently-running searches.
      process.send(blake_chan, blake.Stop)

      process.send(blake_chan, blake.AppendHistoryFEN(fen))
      let blake_res =
        process.try_call(
          blake_chan,
          blake.Go(movetime: Some(4950), depth: None, reply_to: _),
          4950,
        )

      case blake_res {
        Ok(blake.Response(
          evaluation: Evaluation(
            best_move: Some(best_move),
            ..,
          ),
          ..,
        )) -> {
          let lan = move.to_lan(best_move)
          process.send(blake_chan, blake.DoMoves([lan]))
          process.send(blake_chan, blake.Think)

          wisp.ok() |> wisp.string_body(lan)
        }
        _ -> {
          wisp.internal_server_error()
          |> wisp.string_body("Didn't get a move!!!")
        }
      }
    }
  }
}

type SetVerbosityRequest {
  SetVerbosityRequest(verbosity: yapper.Level)
}

fn set_verbosity_decoder() -> decode.Decoder(SetVerbosityRequest) {
  use verbosity_str <- decode.field("verbosity", decode.string)

  case verbosity_str {
    "debug" -> decode.success(SetVerbosityRequest(yapper.Debug))
    "info" -> decode.success(SetVerbosityRequest(yapper.Info))
    "warn" -> decode.success(SetVerbosityRequest(yapper.Warn))
    "err" -> decode.success(SetVerbosityRequest(yapper.Err))
    _ -> decode.failure(SetVerbosityRequest(yapper.Info), "debug|info|warn|err")
  }
}

fn set_verbosity(request, robot) {
  let Robot(yapper_chan:, ..) = robot
  use body <- wisp.require_string_body(request)
  case json.parse(body, set_verbosity_decoder()) {
    Error(_) -> wisp.bad_request()
    Ok(SetVerbosityRequest(level)) -> {
      process.send(yapper_chan, yapper.SetLevel(level))
      wisp.ok() |> wisp.string_body("ok")
    }
  }
}
