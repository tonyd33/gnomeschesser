import chess/game
import chess/move
import chess/player
import chess/robot
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/json
import gleam/option.{type Option, None, Some}
import mist
import wisp.{type Request, type Response}
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let robot_mailbox = process.new_subject()
  let handler_mailbox = process.new_subject()

  let assert Ok(_) =
    handle_request(_, robot_mailbox, handler_mailbox)
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(8000)
    |> mist.start_http

  robot.run(robot_mailbox, handler_mailbox)
}

fn handle_request(
  request: Request,
  robot_mailbox: Subject(robot.UpdateMessage),
  handler_mailbox: Subject(robot.ResponseMessage),
) -> Response {
  case wisp.path_segments(request) {
    ["move"] -> handle_move(request, robot_mailbox, handler_mailbox)
    _ -> wisp.ok()
  }
}

fn move_decoder() -> decode.Decoder(#(String, player.Player, List(String))) {
  use fen <- decode.field("fen", decode.string)
  use turn <- decode.field("turn", player.player_decoder())
  use failed_moves <- decode.field("failed_moves", decode.list(decode.string))
  decode.success(#(fen, turn, failed_moves))
}

fn handle_move(
  request: Request,
  robot_mailbox: Subject(robot.UpdateMessage),
  handler_mailbox: Subject(robot.ResponseMessage),
) -> Response {
  use body <- wisp.require_string_body(request)
  let decode_result = json.parse(body, move_decoder())
  case decode_result {
    Error(_) -> wisp.bad_request()
    Ok(move) -> {
      process.send(robot_mailbox, robot.NewFen(move.0))
      let move_result = get_best_move_at_timeout(4900, handler_mailbox)
      case move_result {
        Ok(move) -> wisp.ok() |> wisp.string_body(move)
        Error(Nil) ->
          wisp.internal_server_error()
          |> wisp.string_body("Didn't get a move")
      }
    }
  }
}

fn get_best_move_at_timeout(
  timeout: Int,
  handler_mailbox: Subject(robot.ResponseMessage),
) -> Result(move.SAN, Nil) {
  process.send_after(handler_mailbox, timeout, robot.Timeout)
  do_get_best_move_at_timeout(None, handler_mailbox)
}

fn do_get_best_move_at_timeout(
  best_move: Option(move.SAN),
  handler_mailbox: Subject(robot.ResponseMessage),
) -> Result(move.SAN, Nil) {
  let message = process.receive_forever(handler_mailbox)
  case message {
    robot.Timeout -> option.to_result(best_move, Nil)
    robot.NewBestMove(move) ->
      do_get_best_move_at_timeout(Some(move), handler_mailbox)
  }
}
