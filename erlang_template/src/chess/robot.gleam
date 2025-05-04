import chess/game
import chess/search
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/function
import gleam/option.{type Option, None, Some}
import gleam/time/timestamp

pub opaque type Robot {
  Robot(main_subject: Subject(UpdateMessage))
}

type UpdateMessage {
  UpdateFen(fen: String, failed_moves: List(game.SAN))
  UpdateBestMove(
    move: game.Move,
    game: game.GameHash,
    memo: search.TranspositionTable,
  )
  GetBestMove(response: Subject(Result(game.SAN, Nil)))
}

type RobotState {
  RobotState(
    game: game.Game,
    best_move: Option(game.Move),
    searcher: #(process.Pid, Subject(search.SearchMessage)),
    memo: search.TranspositionTable,
  )
}

pub fn init() -> Robot {
  Robot(main_subject: create_robot_thread())
}

// This updates the robot with a new FEN (which will start a search)
pub fn update_fen(
  robot: Robot,
  fen: String,
  failed_moves: List(game.SAN),
) -> Nil {
  process.send(robot.main_subject, UpdateFen(fen:, failed_moves:))
}

// Then requests the best move after a delay (in millisecond)
pub fn get_best_move_after(robot: Robot, delay: Int) -> Result(game.SAN, Nil) {
  process.sleep(delay)
  process.call_forever(robot.main_subject, GetBestMove)
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
        game.load_fen(game.start_fen)

      let memo = search.tt_new(timestamp.system_time())
      // The search_subject will be used by searchers to update new best moves found
      let search_subject: Subject(search.SearchMessage) = process.new_subject()

      let searcher_pid = search.new(game, memo, search_subject)
      main_loop(
        RobotState(
          game:,
          best_move: None,
          searcher: #(searcher_pid, search_subject),
          memo:,
        ),
        // This selector allows is to merge the different subjects (like from the searcher) into one selector
        process.new_selector()
          |> process.selecting(robot_subject, function.identity)
          |> process.selecting(search_subject, fn(search) {
            UpdateBestMove(
              search.best_move,
              search.game,
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
  let message = process.select_forever(update)
  let state = case message {
    // If we receive a new FEN, respawn the searcher with the new game
    UpdateFen(fen, _failed_moves) -> {
      let assert Ok(game) = game.load_fen(fen)
      update_game(state, game)
    }
    // If we receive a request for the best move, respond with the current best move we're tracking
    GetBestMove(response) -> {
      case state.best_move {
        Some(best_move) -> {
          let san = game.move_to_san(best_move, state.game)
          process.send(response, Ok(san))

          echo "requested best move"
          // TODO: generate the new game in a much better way
          echo best_move
          let assert Ok(new_game) = game.apply(state.game, best_move)

          update_game(state, new_game)
        }
        _ -> {
          process.send(response, Error(Nil))
          state
        }
      }
    }
    // If we receive an update for the best move, just update the state
    UpdateBestMove(best_move, game, memo) -> {
      case game == game.to_hash(state.game) {
        True -> RobotState(..state, best_move: Some(best_move), memo:)
        False -> {
          echo "received best move for incorrect game"
          RobotState(..state, memo:)
        }
      }
    }
  }

  main_loop(state, update)
}

fn update_game(state: RobotState, game: game.Game) -> RobotState {
  let RobotState(_game, _best_move, #(search_pid, search_subject), memo) = state

  let new_search_pid = search.new(game, memo, search_subject)

  // TODO: check for collision, then add to state
  let best_move =
    case dict.get(memo.dict, game.to_hash(game)) {
      Ok(search.TranspositionEntry(_, search.Evaluation(_, _, best_move), _)) ->
        best_move
      Error(Nil) -> None
    }

  // TODO: don't restart searcher if it's the same game
  process.kill(search_pid)
  RobotState(game, best_move, #(new_search_pid, search_subject), memo)
}
