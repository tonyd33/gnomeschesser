import chess/game
import chess/move
import chess/search
import chess/zobrist
import gleam/bool
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/function
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/timestamp

pub opaque type Robot {
  Robot(main_subject: Subject(RobotMessage))
}

type RobotMessage {
  UpdateGame(game: game.Game)
  SearcherMessage(message: search.SearchMessage)
  GetBestEvaluation(response: Subject(Result(search.Evaluation, Nil)))
}

type RobotState {
  RobotState(
    game: game.Game,
    best_evaluation: Option(search.Evaluation),
    searcher: #(Option(process.Pid), Subject(search.SearchMessage)),
    memo: search.TranspositionTable,
  )
}

pub fn init() -> Robot {
  Robot(main_subject: create_robot_thread())
}

/// This updates the robot with a new FEN (which will start a search)
pub fn update_fen(
  robot: Robot,
  fen: String,
  _failed_moves: List(game.SAN),
) -> Nil {
  let assert Ok(game) = game.load_fen(fen)
  process.send(robot.main_subject, UpdateGame(game))
}

/// Then requests the best move
pub fn get_best_move(
  robot: Robot,
) -> Result(move.Move(move.ValidInContext), Nil) {
  use evaluation <- result.then(process.call_forever(
    robot.main_subject,
    GetBestEvaluation,
  ))
  option.to_result(evaluation.best_move, Nil)
}

/// Spawn a robot thread with the default initial game and also a searcher
fn create_robot_thread() -> Subject(RobotMessage) {
  // The reply_subject is only to receive the robot's subject and return it
  let reply_subject = process.new_subject()
  process.start(
    fn() {
      let robot_subject: Subject(RobotMessage) = process.new_subject()
      process.send(reply_subject, robot_subject)

      let assert Ok(game): Result(game.Game, Nil) =
        game.load_fen(game.start_fen)

      let memo = search.tt_new(timestamp.system_time())
      // The search_subject will be used by searchers to update new best moves found
      let search_subject: Subject(search.SearchMessage) = process.new_subject()
      let search_pid =
        search.new(game, memo, search_subject, search.default_search_opts)

      main_loop(
        RobotState(
          game:,
          best_evaluation: None,
          searcher: #(Some(search_pid), search_subject),
          memo:,
        ),
        // This selector allows is to merge the different subjects (like from the searcher) into one selector
        process.new_selector()
          |> process.selecting(robot_subject, function.identity)
          |> process.selecting(search_subject, SearcherMessage),
      )
    },
    True,
  )
  process.receive_forever(reply_subject)
}

/// The main robot loop that checks for messages and updates the state
fn main_loop(state: RobotState, update: process.Selector(RobotMessage)) {
  let message = process.select_forever(update)
  let state = case message {
    UpdateGame(game) -> update_state_with_new_game(state, game)
    GetBestEvaluation(response:) -> {
      state.best_evaluation
      |> option.to_result(Nil)
      |> process.send(response, _)

      io.println_error("Requested best move")
      echo state.best_evaluation

      // We should do any cleanup or extra calculations while the opponent has their turn
      case state.best_evaluation {
        Some(search.Evaluation(_, _, Some(best_move), _)) -> {
          // We can be certain that it's the correct move for the game
          // otherwise we wouldn't have updated it previously
          let new_game = game.apply(state.game, best_move)
          update_state_with_new_game(state, new_game)
        }
        _ -> state
      }
    }
    // Handles any updates from the searcher
    SearcherMessage(message) ->
      case message {
        search.SearchUpdate(best_evaluation:, game:, transposition: memo) ->
          case game.equal(game, state.game) {
            True ->
              RobotState(..state, best_evaluation: Some(best_evaluation), memo:)
            False -> {
              echo "received best move for incorrect game"
              RobotState(..state, memo:)
            }
          }
        // TODO: We might want to send a response early
        search.SearchDone(best_evaluation:, game:, transposition: memo) ->
          case game.equal(game, state.game) {
            True ->
              RobotState(..state, best_evaluation: Some(best_evaluation), memo:)
            False -> {
              echo "received best move for incorrect game"
              RobotState(..state, memo:)
            }
          }
      }
  }

  main_loop(state, update)
}

fn update_state_with_new_game(state: RobotState, game: game.Game) -> RobotState {
  use <- bool.guard(game.equal(game, state.game), state)

  // TODO: don't restart searcher if it's the same game state
  option.map(state.searcher.0, fn(pid) {
    process.unlink(pid)
    process.kill(pid)
  })

  let search_pid =
    search.new(game, state.memo, state.searcher.1, search.default_search_opts)

  // TODO: check for collision before adding to state
  let best_evaluation = case dict.get(state.memo.dict, zobrist.hash(game)) {
    Ok(search.TranspositionEntry(_, best_evaluation, _)) ->
      Some(best_evaluation)
    Error(Nil) -> None
  }

  RobotState(
    ..state,
    searcher: #(Some(search_pid), state.searcher.1),
    game:,
    best_evaluation:,
  )
}
