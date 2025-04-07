import chess/game.{type Game}
import gleam/erlang/process.{type Subject}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

pub opaque type Robot {
  Robot(subject: Subject(UpdateMessage))
}

type UpdateMessage {
  Update(
    fen: String,
    failed_moves: List(game.SAN),
    response_subject: Subject(ResponseMessage),
  )
}

type ResponseMessage {
  Timeout
  NewBestMove(move: game.SAN)
}

pub fn init() -> Robot {
  let subject = process.new_subject()
  process.start(
    fn() {
      let assert Ok(initial_state) =
        game.load_fen(
          "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        )
      main_loop(initial_state, subject, None)
    },
    True,
  )
  Robot(subject:)
}

pub fn get_best_move(
  robot: Robot,
  fen: String,
  failed_moves: List(game.SAN),
) -> Result(game.SAN, Nil) {
  let response_subject = process.new_subject()
  process.send_after(response_subject, 4900, Timeout)
  process.send(robot.subject, Update(fen:, failed_moves:, response_subject:))
  do_get_best_move(response_subject)
}

fn do_get_best_move(subject: Subject(ResponseMessage)) -> Result(game.SAN, Nil) {
  case process.receive(subject, 7500) {
    Error(Nil) -> panic as "Never received the timeout"
    Ok(Timeout) -> Error(Nil)
    Ok(NewBestMove(move)) -> do_get_best_move(subject) |> result.or(Ok(move))
  }
}

fn main_loop(
  state: Game,
  update: Subject(UpdateMessage),
  response_subject: Option(Subject(ResponseMessage)),
) {
  let message = process.receive(update, 0)
  let #(state, response_subject) = case message {
    Ok(Update(_fen, _failed_moves, response_subject)) -> {
      let new_state = state
      // update game and state and stuff
      #(new_state, Some(response_subject))
    }
    Error(Nil) -> #(state, response_subject)
  }

  let assert Ok(new_best_move) =
    game.moves(state) |> list.first |> result.map(game.move_to_san)
  // perform another step of the calculations

  case response_subject {
    Some(response_subject) ->
      process.send(response_subject, NewBestMove(new_best_move))
    None -> Nil
  }

  main_loop(state, update, response_subject)
}
