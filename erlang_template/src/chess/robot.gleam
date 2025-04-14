import chess/evaluate
import chess/game
import gleam/bool
import gleam/erlang/process.{type Subject}
import gleam/int
import gleam/option.{type Option, None, Some}

pub opaque type Robot {
  Robot(main_subject: Subject(UpdateMessage))
}

type UpdateMessage {
  Update(
    fen: String,
    failed_moves: List(game.SAN),
    handler_subject: Subject(HandlerMessage),
  )
}

type HandlerMessage {
  GetBestMove(response: Subject(game.SAN))
  UpdateBestMove(move: game.SAN)
}

type RobotState {
  RobotState(
    game: game.Game,
    current_search_depth: Int,
    evaluation_memoization: evaluate.MemoizationObject,
  )
}

pub fn init() -> Robot {
  Robot(main_subject: create_robot_thread())
}

pub fn get_best_move(
  robot: Robot,
  fen: String,
  failed_moves: List(game.SAN),
) -> Result(game.SAN, Nil) {
  // we spawn a handler thread to keep track of all the current best moves
  // also because the wisp actor doesn't like if we spam it
  let handler_subject = create_handler_thread()
  process.send(
    robot.main_subject,
    Update(fen:, failed_moves:, handler_subject:),
  )
  process.sleep(4950)
  let best_move = process.call_forever(handler_subject, GetBestMove)
  // TODO: kill this thread properly
  //process.send_after(handler_subject, 1000, Kill)
  Ok(best_move)
}

fn create_robot_thread() -> Subject(UpdateMessage) {
  let reply_subject = process.new_subject()
  process.start(
    fn() {
      let assert Ok(game) =
        game.load_fen(
          "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        )
      let robot = process.new_subject()
      process.send(reply_subject, robot)
      main_loop(
        RobotState(
          game:,
          current_search_depth: 1,
          evaluation_memoization: evaluate.new_memoization_object(),
        ),
        robot,
        None,
      )
    },
    True,
  )
  process.receive_forever(reply_subject)
}

fn create_handler_thread() -> Subject(HandlerMessage) {
  let reply_subject = process.new_subject()
  process.start(
    fn() {
      let handler_subject = process.new_subject()
      process.send(reply_subject, handler_subject)
      handler_loop(handler_subject, None)
    },
    True,
  )
  process.receive_forever(reply_subject)
}

fn handler_loop(
  handler_subject: Subject(HandlerMessage),
  best_move: Option(game.SAN),
) -> Nil {
  case process.receive_forever(handler_subject) {
    UpdateBestMove(move) -> handler_loop(handler_subject, Some(move))
    GetBestMove(response) -> {
      case best_move {
        Some(move) -> process.send(response, move)
        None -> {
          process.send_after(handler_subject, 100, GetBestMove(response))
          handler_loop(handler_subject, best_move)
        }
      }
    }
  }
}

fn main_loop(
  state: RobotState,
  update: Subject(UpdateMessage),
  handler_subject: Option(Subject(HandlerMessage)),
) {
  // TODO: make this 0
  let message = process.receive(update, 1)
  let #(state, handler_subject) = case message {
    Ok(Update(fen, _failed_moves, handler_subject)) -> {
      use <- bool.guard(
        !process.is_alive(process.subject_owner(handler_subject)),
        #(state, None),
      )
      let RobotState(game, search_depth, memo) = state
      let assert Ok(game) = game.load_fen(fen)
      #(RobotState(game, search_depth - 1, memo), Some(handler_subject))
    }
    Error(Nil) -> #(state, handler_subject)
  }

  let RobotState(game, search_depth, memo) = state

  let #(evaluate.Evaluation(_score, best_move), memo) =
    evaluate.search(game, search_depth, memo)

  case best_move, handler_subject {
    Some(best_move), Some(handler_subject) ->
      process.send(handler_subject, UpdateBestMove(game.move_to_san(best_move)))
    _, _ -> Nil
  }

  // TODO: adjust depth properly
  main_loop(
    RobotState(game, int.min(search_depth + 1, 3), memo),
    update,
    handler_subject,
  )
}
