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
import gleam/pair
import gleam/result
import gleam/time/timestamp
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
  SetFen(fen: String)
  ApplyMove(lan: String)
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
        // Update the current game position
        SetFen(fen:) -> {
          let game = game.load_fen(fen) |> option.from_result
          RobotState(..state, game:, best_evaluation: None)
        }
        Clear -> {
          option.map(state.searcher.0, fn(pid) {
            process.unlink(pid)
            process.kill(pid)
          })
          let search_state = search_state.new(timestamp.system_time())
          RobotState(
            ..state,
            search_state:,
            searcher: #(None, state.searcher.1),
            game: None,
            best_evaluation: None,
          )
        }
        ApplyMove(lan:) -> {
          // insert the previous game into the previous_games of search_state
          // so that we can check it for 3 fold repetition
          let search_state =
            option.map(state.game, fn(game) {
              let search_state = state.search_state
              let previous_games =
                search_state.previous_games
                |> dict.insert(game.hash(game), game)
              search_state.SearchState(..search_state, previous_games:)
            })
            |> option.unwrap(state.search_state)
          let game =
            state.game
            |> option.then(fn(game) {
              case game.validate_move(move.from_lan(lan), game) {
                Ok(valid_move) -> Some(game.apply(game, valid_move))
                Error(Nil) -> None
              }
            })
          RobotState(..state, game:, search_state:)
        }
        IsReady -> {
          io.println(uci.serialize_gui_cmd(uci.GUICmdReadyOk))
          state
        }

        // Messages we receive from the Searcher process
        SearcherMessage(message) ->
          case message {
            search.SearchUpdate(best_evaluation:, game:) -> {
              case option.map(state.game, game.equal(_, game)) {
                Some(True) -> {
                  let evaluation.Evaluation(
                    score:,
                    node_type:,
                    best_move:,
                    best_line:,
                  ) = best_evaluation
                  option.map(best_move, fn(best_move) {
                    let info_score_list = [
                      uci.ScoreCentipawns(
                        n: xint.to_int(score) |> result.unwrap(0),
                      ),
                      ..case node_type {
                        evaluation.PV -> []
                        evaluation.Cut -> [uci.ScoreLowerbound]
                        evaluation.All -> [uci.ScoreUpperbound]
                      }
                    ]
                    uci.GUICmdInfo([
                      uci.InfoPrincipalVariation([move.to_lan(best_move)]),
                      uci.InfoScore(info_score_list),
                      uci.InfoPrincipalVariation(
                        best_line |> list.map(move.to_lan),
                      ),
                    ])
                    |> uci.serialize_gui_cmd
                    |> io.println
                  })

                  use <- bool.guard(option.is_none(best_move), state)
                  RobotState(..state, best_evaluation: Some(best_evaluation))
                }
                _ -> {
                  echo "received best move for incorrect game"
                  state
                }
              }
            }
            search.SearchDone(best_evaluation:, game: _) -> {
              // We don't respond to this if there's no search active
              case state.searcher.0 {
                Some(pid) -> {
                  let evaluation.Evaluation(_, _, best_move, _) =
                    best_evaluation
                  option.map(best_move, fn(best_move) {
                    uci.GUICmdBestMove(
                      move: move.to_lan(best_move),
                      ponder: None,
                    )
                    |> uci.serialize_gui_cmd
                    |> io.println
                  })
                  process.unlink(pid)
                  process.kill(pid)

                  RobotState(..state, searcher: #(None, state.searcher.1))
                }
                None -> state
              }
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
          // We don't respond to this if there's no search active
          case state.searcher.0 {
            Some(pid) -> {
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
              process.unlink(pid)
              process.kill(pid)

              RobotState(..state, searcher: #(None, state.searcher.1))
            }
            None -> state
          }
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
            search.new(game, state.search_state, state.searcher.1, search_opts)
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
