import chess/game
import chess/player
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/json
import mist
import wisp.{type Request, type Response}
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    handle_request
    |> wisp_mist.handler(secret_key_base)
    |> mist.new
    |> mist.bind("0.0.0.0")
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}

fn handle_request(request: Request) -> Response {
  case wisp.path_segments(request) {
    ["move"] -> handle_move(request)
    _ -> wisp.ok()
  }
}

fn move_decoder() {
  use fen <- decode.field("fen", decode.string)
  use turn <- decode.field("turn", player.player_decoder())
  use failed_moves <- decode.field("failed_moves", decode.list(decode.string))
  decode.success(#(fen, turn, failed_moves))
}

fn handle_move(request: Request) -> Response {
  use body <- wisp.require_string_body(request)
  let decode_result = json.parse(body, move_decoder())
  case decode_result {
    Error(_) -> wisp.bad_request()
    Ok(move) -> {
      let move_result = game.move(move.0, move.1, move.2)
      case move_result {
        Ok(move) -> wisp.ok() |> wisp.string_body(move)
        Error(reason) ->
          wisp.internal_server_error() |> wisp.string_body(reason)
      }
    }
  }
}
