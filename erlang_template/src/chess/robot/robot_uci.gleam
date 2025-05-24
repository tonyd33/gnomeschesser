import chess/actors/auditor
import chess/game
import chess/move
import chess/piece
import chess/player
import chess/search
import chess/search/evaluation
import chess/search/game_history
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
    searcher: #(
      Option(process.Pid),
      Subject(search.SearchMessage),
      Option(process.Pid),
      Subject(search.SearchMessage),
    ),
    search_state: search_state.SearchState,
    subject: Subject(RobotMessage),
    game_history: game_history.GameHistory,
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

      let auditor_channel = auditor.start()
      let search_state =
        search_state.new(timestamp.system_time(), auditor_channel)
      // The search_subject will be used by searchers to update new best moves found
      let search_subject_1: Subject(search.SearchMessage) =
        process.new_subject()

      // The search_subject will be used by searchers to update new best moves found
      let search_subject_2: Subject(search.SearchMessage) =
        process.new_subject()

      main_loop(
        RobotState(
          game: None,
          best_evaluation: None,
          searcher: #(None, search_subject_1, None, search_subject_2),
          search_state: search_state,
          subject: robot_subject,
          game_history: game_history.new(),
        ),
        // This selector allows is to merge the different subjects (like from the searcher) into one selector
        process.new_selector()
          |> process.selecting(robot_subject, function.identity)
          |> process.selecting(search_subject_1, SearcherMessage),
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
          let game_history = game_history.new()
          let game_history =
            game
            |> option.map(game_history.insert(game_history, _))
            |> option.unwrap(game_history)
          RobotState(..state, game:, best_evaluation: None, game_history:)
        }
        Clear -> {
          option.map(state.searcher.0, fn(pid) {
            process.unlink(pid)
            process.kill(pid)
          })
          let auditor_channel = auditor.start()
          RobotState(
            ..state,
            search_state: search_state.new(
              timestamp.system_time(),
              auditor_channel,
            ),
            searcher: #(None, state.searcher.1, None, state.searcher.3),
            game: None,
            game_history: game_history.new(),
            best_evaluation: None,
          )
        }
        ApplyMove(lan:) ->
          {
            use game <- option.then(state.game)
            use valid_move <- option.map(
              move.from_lan(lan)
              |> game.validate_move(game)
              |> option.from_result,
            )
            let game = game.apply(game, valid_move)
            let game_history = game_history.insert(state.game_history, game)

            RobotState(..state, game: Some(game), game_history:)
          }
          |> option.unwrap(state)

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
            ) -> {
              case option.map(state.game, game.equal(_, game)) {
                Some(True) -> {
                  let evaluation.Evaluation(
                    score:,
                    node_type:,
                    best_move:,
                    best_line:,
                  ) = best_evaluation

                  let info_score_list =
                    [
                      // TODO: Give proper mate score
                      // Why are we sending these scores for the infinite
                      // cases? Idk I think it stops fastchess warnings lol
                      case score {
                        xint.PosInf -> [
                          uci.ScoreMate(1),
                          uci.ScoreCentipawns(n: 1),
                        ]
                        xint.Finite(score) -> [uci.ScoreCentipawns(n: score)]
                        xint.NegInf -> [
                          uci.ScoreMate(1),
                          uci.ScoreCentipawns(n: 1),
                        ]
                      },
                      case node_type {
                        evaluation.PV -> []
                        evaluation.Cut -> [uci.ScoreLowerbound]
                        evaluation.All -> [uci.ScoreUpperbound]
                      },
                    ]
                    |> list.flatten
                  uci.GUICmdInfo([
                    uci.InfoDepth(depth),
                    uci.InfoScore(info_score_list),
                    uci.InfoNodes(nodes_searched),
                    uci.InfoTime(time),
                    uci.InfoNodesPerSecond(nps),
                    // TODO: Keep track of this
                    uci.InfoHashFull(0),
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

          let search_opts = search.SearchOpts(depth, 1)
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
            searcher: #(None, state.searcher.1, None, state.searcher.3),
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
              state.game_history,
            )
            |> Some
          RobotState(
            ..state,
            searcher: #(
              search_pid,
              state.searcher.1,
              search_pid,
              state.searcher.3,
            ),
            best_evaluation: None,
          )
        }
      }
    None -> panic as "No game existed when searcher is starting!"
  }
}
