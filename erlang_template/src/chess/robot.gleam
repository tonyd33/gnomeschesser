import chess/game
import chess/search
import gleam/erlang/process.{type Subject}
import gleam/function
import gleam/option.{type Option, None, Some}

pub opaque type Robot {
  Robot(main_subject: Subject(UpdateMessage))
}

type UpdateMessage {
  UpdateFen(fen: String, failed_moves: List(game.SAN))
  UpdateBestMove(move: game.SAN, memo: search.TranspositionTable)
  GetBestMove(response: Subject(game.SAN))
}

type RobotState {
  RobotState(
    game: game.Game,
    best_move: Option(game.SAN),
    searcher: #(process.Pid, Subject(search.SearchMessage)),
    memo: search.TranspositionTable,
  )
}

pub fn init() -> Robot {
  Robot(main_subject: create_robot_thread())
}

// This requests the best move given a certain FEN
// It will update the robot with the FEN, wait 4.95 seconds
// Then send a request for the best move
pub fn get_best_move(
  robot: Robot,
  fen: String,
  failed_moves: List(game.SAN),
) -> Result(game.SAN, Nil) {
  process.send(robot.main_subject, UpdateFen(fen:, failed_moves:))
  process.sleep(4950)
  let best_move = process.call_forever(robot.main_subject, GetBestMove)
  Ok(best_move)
}

// Spawn a robot thread with the default initial game and also a searcher
fn create_robot_thread() -> Subject(UpdateMessage) {
  // The reply_subject is only to receive the robot's subject and return it
  let reply_subject = process.new_subject()
  process.start(
    fn() {
      let robot_subject: Subject(UpdateMessage) = process.new_subject()
      process.send(reply_subject, robot_subject)

      let assert Ok(game): Result(game.Game, Nil) =
        game.load_fen(
          "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        )
      let memo = search.memoization_new()
      // The search_subject will be used by searchers to update new best moves found
      let search_subject: Subject(search.SearchMessage) = process.new_subject()

      let searcher_pid = search.new(game, memo, search_subject)
      main_loop(
        RobotState(
          game:,
          best_move: None,
          searcher: #(searcher_pid, search_subject),
          memo: memo,
        ),
        // This selector allows is to merge the different subjects (like from the searcher) into one selector
        process.new_selector()
          |> process.selecting(robot_subject, function.identity)
          |> process.selecting(search_subject, fn(search) {
            UpdateBestMove(
              game.move_to_san(search.best_move),
              search.transposition,
            )
          }),
      )
    },
    True,
  )
  process.receive_forever(reply_subject)
}

// The main robot loop that checks for messages and updates the state
fn main_loop(state: RobotState, update: process.Selector(UpdateMessage)) {
  let message = process.select(update, 0)
  let state = case message {
    // If we receive a new FEN, respawn the searcher with the new game
    Ok(UpdateFen(fen, _failed_moves)) -> {
      let RobotState(_game, _best_move, #(search_pid, search_subject), memo) =
        state

      process.kill(search_pid)

      let assert Ok(game) = game.load_fen(fen)
      let searcher_pid = search.new(game, memo, search_subject)
      RobotState(game, None, #(searcher_pid, search_subject), memo)
    }
    // If we receive a request for the best move, respond with the current best move we're tracking
    Ok(GetBestMove(response)) -> {
      case state.best_move {
        Some(best_move) -> process.send(response, best_move)
        _ -> Nil
        //panic as "No best move was calculated in time"
      }
      state
    }
    // If we receive an update for the best move, just update the state
    Ok(UpdateBestMove(best_move, memo)) ->
      RobotState(..state, best_move: Some(best_move), memo:)
    // If there's no message, just maintain the same state
    Error(Nil) -> state
  }

  main_loop(state, update)
}
