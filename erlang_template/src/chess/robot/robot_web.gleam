import chess/game
import chess/move
import chess/search
import chess/search/evaluation
import chess/search/game_history
import chess/search/search_state
import chess/search/transposition
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
  ApplyMove(move: move.Move(move.ValidInContext))
  UpdateGame(game: game.Game)
  SearcherMessage(message: search.SearchMessage)
  GetBestEvaluation(response: Subject(Result(evaluation.Evaluation, Nil)))
}

type RobotState {
  RobotState(
    game: game.Game,
    best_evaluation: Option(evaluation.Evaluation),
    searcher: #(Option(process.Pid), Subject(search.SearchMessage)),
    search_state: search_state.SearchState,
    game_history: game_history.GameHistory,
  )
}

pub fn init() -> Robot {
  Robot(main_subject: create_robot_thread())
}

/// Updates the robot to specified FEN and then
/// waits a certain number of milliseconds before getting
/// the best move
/// If there's only 1 move the robot responds immediately 
pub fn get_best_move_from_fen_by(
  robot: Robot,
  fen: String,
  by: Int,
) -> Result(move.Move(move.ValidInContext), Nil) {
  let assert Ok(game) = game.load_fen(fen)
  process.send(robot.main_subject, UpdateGame(game))

  let valid_moves = game.valid_moves(game)
  case valid_moves {
    [] -> Error(Nil)
    [one_move] -> {
      process.send(robot.main_subject, ApplyMove(one_move))
      one_move |> Ok
    }
    _ -> {
      // TODO: adjust the sleep duration so that it's more precise from any work done in between
      // atm it looks like there's no delay anyways?
      process.sleep(by)
      use evaluation <- result.then(process.call_forever(
        robot.main_subject,
        GetBestEvaluation,
      ))
      option.to_result(evaluation.best_move, Nil)
    }
  }
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
      let game_history = game_history.new() |> game_history.insert(game)

      let search_state = search_state.new(timestamp.system_time())
      // The search_subject will be used by searchers to update new best moves found
      let search_subject: Subject(search.SearchMessage) = process.new_subject()

      let search_pid =
        search.new(
          game,
          search_state,
          search_subject,
          search.default_search_opts,
          game_history,
        )

      main_loop(
        RobotState(
          game:,
          best_evaluation: None,
          searcher: #(Some(search_pid), search_subject),
          search_state:,
          game_history:,
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
    ApplyMove(move) ->
      game.apply(state.game, move)
      |> update_state_with_new_game(state, _)
    GetBestEvaluation(response:) -> {
      state.best_evaluation
      |> option.to_result(Nil)
      |> process.send(response, _)

      io.println_error("Requested best move")
      //echo state.best_evaluation

      // We should do any cleanup or extra calculations while the opponent has their turn
      // TODO: prune the transposition table here instead
      case state.best_evaluation {
        Some(evaluation.Evaluation(_, _, Some(best_move), _)) -> {
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
        search.SearchUpdate(best_evaluation:, game:, ..) ->
          case game.equal(game, state.game) {
            True -> RobotState(..state, best_evaluation: Some(best_evaluation))
            False -> {
              echo "received best move for incorrect game"
              state
            }
          }
        // TODO: We might want to send a response early
        // We could have a signal for the searcher to indicate
        // How confident it thinks a move is
        search.SearchDone ->
          panic as "The searcher can't be done on the web version"
        search.SearchStateUpdate(search_state:) ->
          RobotState(..state, search_state:)
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

  let game_history = game_history.insert(state.game_history, game)

  let search_pid =
    search.new(
      game,
      state.search_state,
      state.searcher.1,
      search.default_search_opts,
      state.game_history,
    )

  // TODO: check if the retrieved evaluation is actually valid for the given game
  // this could be false due to collision
  // TODO: just remove this because we're now confident that it will return a move in time
  // TODO: or generate a random move instead?
  let best_evaluation = case
    dict.get(state.search_state.transposition, game.hash(game))
  {
    Ok(transposition.Entry(_, best_evaluation, _)) -> Some(best_evaluation)
    Error(Nil) -> None
  }

  RobotState(
    searcher: #(Some(search_pid), state.searcher.1),
    game:,
    best_evaluation:,
    search_state: state.search_state,
    game_history:,
  )
}
