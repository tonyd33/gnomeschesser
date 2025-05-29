import chess/evaluate
import chess/game
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/json
import mist
import util/xint
import wisp.{type Request, type Response}
import wisp/wisp_mist

pub fn main() {
  let assert Ok(game) =
    game.load_fen(
      "r1bqkbnr/ppp1pppp/2n5/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2",
    )
  echo evaluate.compute_batched_scores(game)
  let assert Ok(game) =
    game.load_fen(
      "r1bqkbnr/ppp1pppp/2n5/3p4/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 2",
    )
  echo evaluate.compute_batched_scores(game)
  // wisp.configure_logger()
  // let secret_key_base = wisp.random_string(64)
  //
  // let assert Ok(_) =
  //   handle_request
  //   |> wisp_mist.handler(secret_key_base)
  //   |> mist.new
  //   |> mist.bind("0.0.0.0")
  //   |> mist.port(8000)
  //   |> mist.start_http
  //
  // process.sleep_forever()
}

fn handle_request(request: Request) -> Response {
  case wisp.path_segments(request) {
    ["evaluate"] -> handle_move(request)
    _ -> wisp.ok()
  }
}

type EvaluationRequest {
  EvaluationRequest(fen: String)
}

fn evaluation_decoder() -> decode.Decoder(EvaluationRequest) {
  use fen <- decode.field("fen", decode.string)
  decode.success(EvaluationRequest(fen:))
}

fn handle_move(request: Request) -> Response {
  use body <- wisp.require_string_body(request)
  case json.parse(body, evaluation_decoder()) {
    Error(_) -> wisp.bad_request()
    Ok(EvaluationRequest(fen:)) -> {
      let assert Ok(game) = game.load_fen(fen)
      let evaluation = evaluate.game(game)

      wisp.ok()
      |> wisp.string_body(xint.to_string(evaluation))
    }
  }
}
