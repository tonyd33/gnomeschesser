import chess/game
import chess/move
import chess/player
import chess/search
import chess/search/evaluation
import chess/search/search_state
import chess/uci
import gleam/bool
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/function
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/time/timestamp
import util/dict_addons
import util/xint

const name = "TODO: name"

const authors = "TODO: authors"

pub type Robot {
  Robot(subject: Subject(RobotMessage))
}

pub fn init() -> Robot {
  Robot(subject: create_robot_thread())
}

pub type RobotMessage {
  // Messages we receive from the UCI interface
  UciStart
  IsReady
  Clear
  PositionFEN(fen: String, moves: List(String))
  PositionStartPos(moves: List(String))
  GoClock(
    white_time: Int,
    black_time: Int,
    white_increment: Int,
    black_increment: Int,
  )
  GoGeneral(time: Option(Int), depth: Option(Int))
  GoInfinite
  Stop
  // Messages we receive from the Searcher process
  SearcherMessage(message: search.SearchMessage)
}

type RobotState {
  RobotState(
    game: Option(game.Game),
    history: List(game.Game),
    best_evaluation: Option(evaluation.Evaluation),
    searcher: #(Option(process.Pid), Subject(search.SearchMessage)),
    search_state: search_state.SearchState,
    subject: Subject(RobotMessage),
  )
}

/// Spawn a robot thread with the default initial game and also a searcher
fn create_robot_thread() -> Subject(RobotMessage) {
  // The reply_subject is only to receive the robot's subject and return it
  let reply_subject = process.new_subject()
  process.start(
    fn() {
      let robot_subject: Subject(RobotMessage) = process.new_subject()
      process.send(reply_subject, robot_subject)

      let search_state = search_state.new(timestamp.system_time())
      // The search_subject will be used by searchers to update new best moves found
      let search_subject: Subject(search.SearchMessage) = process.new_subject()

      main_loop(
        RobotState(
          game: None,
          history: [],
          best_evaluation: None,
          searcher: #(None, search_subject),
          search_state:,
          subject: robot_subject,
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

fn set_fen(state, fen, moves) {
  let robot_result = {
    use initial_game <- result.try(game.load_fen(fen))

    // Construct the head and tail of the game
    // #(game_n, [game_{n-1}, game_{n-2}, ..., .game_1])
    use #(game, history) <- result.try({
      use ht, lan <- list.fold(moves, Ok(#(initial_game, [])))
      use #(head, tail) <- result.try(ht)

      use move <- result.try(game.validate_move(move.from_lan(lan), head))
      let head1 = game.apply(head, move)
      Ok(#(head1, [head, ..tail]))
    })

    Ok(RobotState(..state, game: Some(game), history:))
  }

  case robot_result {
    Ok(new_state) -> new_state
    Error(_) -> {
      echo "Failed to apply the robot result!!"
      state
    }
  }
}

/// The main robot loop that checks for messages and updates the state
fn main_loop(state: RobotState, update: process.Selector(RobotMessage)) {
  let message = process.select(update, 1000)
  let state =
    {
      use message <- result.map(message)
      case message {
        UciStart -> {
          io.println(uci.serialize_gui_cmd(uci.GUICmdId(uci.Name(name))))
          io.println(uci.serialize_gui_cmd(uci.GUICmdId(uci.Author(authors))))
          // We don't offer any options currently, but this is where it would go
          io.println(uci.serialize_gui_cmd(uci.GUICmdUCIOk))
          state
        }
        PositionFEN(fen:, moves:) -> set_fen(state, fen, moves)
        PositionStartPos(moves:) -> set_fen(state, game.start_fen, moves)
        // Update the current game position
        Clear -> {
          option.map(state.searcher.0, fn(pid) {
            process.unlink(pid)
            process.kill(pid)
          })
          RobotState(
            ..state,
            search_state: search_state.new(timestamp.system_time()),
            searcher: #(None, state.searcher.1),
            game: None,
            history: [],
            best_evaluation: None,
          )
        }
        IsReady -> {
          io.println(uci.serialize_gui_cmd(uci.GUICmdReadyOk))
          state
        }
        // Messages we receive from the Searcher process
        SearcherMessage(message) ->
          case message {
            search.SearchUpdate(
              best_evaluation:,
              game:,
              depth:,
              time:,
              nodes_searched:,
              nps:,
              hashfull:,
            ) -> {
              case option.map(state.game, game.equal(_, game)) {
                Some(True) -> {
                  let evaluation.Evaluation(score:, best_move:, best_line:, ..) =
                    best_evaluation

                  let info_score = case score {
                    // TODO: Give proper mate score
                    xint.PosInf -> uci.ScoreMate(-1)
                    xint.Finite(score) -> uci.ScoreCentipawns(n: score)
                    xint.NegInf -> uci.ScoreMate(-1)
                  }
                  uci.GUICmdInfo([
                    uci.InfoDepth(depth),
                    uci.InfoScore(info_score),
                    uci.InfoNodes(nodes_searched),
                    uci.InfoTime(time),
                    uci.InfoNodesPerSecond(nps),
                    uci.InfoHashFull(hashfull),
                    uci.InfoPrincipalVariation(list.map(best_line, move.to_lan)),
                  ])
                  |> uci.serialize_gui_cmd
                  |> io.println

                  use <- bool.guard(option.is_none(best_move), state)
                  RobotState(..state, best_evaluation: Some(best_evaluation))
                }
                _ -> {
                  echo "received best move for incorrect game"
                  state
                }
              }
            }
            search.SearchDone -> {
              process.send(state.subject, Stop)
              state
            }
            search.SearchStateUpdate(search_state:) ->
              RobotState(..state, search_state:)
          }
        GoClock(
          white_time: _,
          black_time: _,
          white_increment:,
          black_increment:,
        ) -> {
          // TODO: it's possible this will mess up if there's no valid game state
          // Then we won't have a searcher, but we will have a Stop message
          case state.game |> option.map(game.turn) {
            Some(player.Black) -> {
              process.send_after(state.subject, black_increment * 19 / 20, Stop)
              Nil
            }
            Some(player.White) -> {
              process.send_after(state.subject, white_increment * 19 / 20, Stop)
              Nil
            }
            None -> Nil
          }
          start_searcher(state, search.default_search_opts)
        }
        GoGeneral(time, depth) -> {
          case time {
            // TODO: it's possible this will mess up if there's no valid game state
            // Then we won't have a searcher, but we will have a Stop message
            Some(time) -> {
              process.send_after(state.subject, time * 9 / 10, Stop)
              Nil
            }
            _ -> Nil
          }

          let search_opts = search.SearchOpts(depth)
          start_searcher(state, search_opts)
        }
        GoInfinite -> start_searcher(state, search.default_search_opts)
        Stop -> {
          option.map(state.searcher.0, fn(pid) {
            process.unlink(pid)
            process.kill(pid)
          })

          case state.best_evaluation {
            Some(evaluation.Evaluation(
              score: _,
              node_type: _,
              best_move: Some(move),
              best_line: _,
            )) ->
              uci.GUICmdBestMove(move: move.to_lan(move), ponder: None)
              |> uci.serialize_gui_cmd
              |> io.println
            _ -> Nil
          }

          RobotState(
            ..state,
            searcher: #(None, state.searcher.1),
            best_evaluation: None,
          )
        }
      }
    }
    |> result.unwrap(state)
  main_loop(state, update)
}

fn start_searcher(
  state: RobotState,
  search_opts: search.SearchOpts,
) -> RobotState {
  option.map(state.searcher.0, fn(pid) {
    process.unlink(pid)
    process.kill(pid)
  })

  // don't bother running the search if there's no valid moves
  case state.game {
    Some(game) ->
      case game.valid_moves(game) {
        [] -> panic as "Search requested on a position with no valid moves!"
        _ -> {
          let search_pid =
            search.new(
              game,
              state.search_state,
              state.searcher.1,
              search_opts,
              dict_addons.zip_dict_by(state.history, game.hash),
            )
            |> Some
          RobotState(
            ..state,
            searcher: #(search_pid, state.searcher.1),
            best_evaluation: None,
          )
        }
      }
    None -> panic as "No game existed when searcher is starting!"
  }
}
