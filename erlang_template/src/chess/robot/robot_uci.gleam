import chess/game
import chess/move
import chess/player
import chess/search
import chess/uci
import gleam/erlang/process.{type Subject}
import gleam/function
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
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
    best_evaluation: Option(search.Evaluation),
    searcher: #(Option(process.Pid), Subject(search.SearchMessage)),
    memo: search.TranspositionTable,
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

      let memo = search.tt_new(timestamp.system_time())
      // The search_subject will be used by searchers to update new best moves found
      let search_subject: Subject(search.SearchMessage) = process.new_subject()

      main_loop(
        RobotState(
          game: None,
          best_evaluation: None,
          searcher: #(None, search_subject),
          memo:,
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
          RobotState(
            ..state,
            searcher: #(None, state.searcher.1),
            game: None,
            best_evaluation: None,
          )
        }
        ApplyMove(lan:) -> {
          let game =
            option.then(state.game, fn(game) {
              case game.validate_move(move.from_lan(lan), game) {
                Ok(valid_move) -> Some(game.apply(game, valid_move))
                Error(Nil) -> None
              }
            })
          RobotState(..state, game:)
        }
        IsReady -> {
          io.println(uci.serialize_gui_cmd(uci.GUICmdReadyOk))
          state
        }

        // Messages we receive from the Searcher process
        SearcherMessage(message) ->
          case message {
            search.SearchUpdate(best_evaluation:, game:, transposition: memo) -> {
              case option.map(state.game, game.equal(_, game)) {
                Some(True) -> {
                  let search.Evaluation(
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
                        search.PV -> []
                        search.Cut -> [uci.ScoreLowerbound]
                        search.All -> [uci.ScoreUpperbound]
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

                  RobotState(
                    ..state,
                    best_evaluation: Some(best_evaluation),
                    memo:,
                  )
                }
                _ -> {
                  echo "received best move for incorrect game"
                  RobotState(..state, memo:)
                }
              }
            }
            search.SearchDone(best_evaluation:, game: _, transposition: memo) -> {
              // We don't respond to this if there's no search active
              case state.searcher.0 {
                Some(pid) -> {
                  let search.Evaluation(_, _, best_move, _) = best_evaluation
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

                  RobotState(
                    ..state,
                    searcher: #(None, state.searcher.1),
                    memo:,
                  )
                }
                None -> RobotState(..state, memo:)
              }
            }
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
                Some(search.Evaluation(
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

  let pid =
    state.game
    |> option.map(search.new(_, state.memo, state.searcher.1, search_opts))

  RobotState(..state, searcher: #(pid, state.searcher.1))
}
