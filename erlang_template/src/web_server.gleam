import chess/game
import chess/move
import chess/player
import chess/robot/robot_web as robot
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/json
import mist
import wisp.{type Request, type Response}
import wisp/wisp_mist

pub fn start_robot() -> Nil {
  let robot = robot.init()

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

fn handle_request(request: Request, robot: robot.Robot) -> Response {
  case wisp.path_segments(request) {
    ["move"] -> handle_move(request, robot)
    _ -> wisp.ok()
  }
}

type MoveRequest {
  MoveRequest(fen: game.SAN, turn: player.Player, failed_moves: List(game.SAN))
}

fn move_decoder() -> decode.Decoder(MoveRequest) {
  use fen <- decode.field("fen", decode.string)
  use turn <- decode.field("turn", player.player_decoder())
  use failed_moves <- decode.field("failed_moves", decode.list(decode.string))
  decode.success(MoveRequest(fen:, turn:, failed_moves:))
}

fn handle_move(request: Request, robot: robot.Robot) -> Response {
  use body <- wisp.require_string_body(request)
  case json.parse(body, move_decoder()) {
    Error(_) -> wisp.bad_request()
    Ok(MoveRequest(fen:, turn: _, failed_moves:)) -> {
      robot.update_fen(robot, fen, failed_moves)

      case robot.get_best_move_from_fen_by(robot, fen, 4900) {
        Ok(move) -> wisp.ok() |> wisp.string_body(move.to_lan(move))
        Error(Nil) ->
          wisp.internal_server_error()
          |> wisp.string_body("Didn't get a move!!!")
      }
    }
  }
}
