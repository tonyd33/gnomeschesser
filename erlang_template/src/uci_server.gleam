import chess/game
import chess/robot/robot_uci as robot
import chess/uci
import gleam/dict
import gleam/erlang
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/option
import gleam/result
import util/parser as p

pub fn start_robot() -> Nil {
  let robot = robot.init()
  process.start(fn() { handle_input(robot) }, True)
  Nil
}

fn handle_input(robot: robot.Robot) {
  let engine_cmd = uci.engine_cmd()
  case erlang.get_line("") {
    Error(erlang.Eof) -> Nil

    Error(erlang.NoData) -> Nil

    Ok(line) -> {
      io.print_error("received: " <> line)
      {
        let parsed = p.run(engine_cmd, line)
        case parsed {
          Ok(uci.EngCmdUCI) -> {
            process.send(robot.subject, robot.UciStart)
          }
          Ok(uci.EngCmdQuit) -> {
            //process.kill(process.self())
            // TODO: figure out why this won't quit
            panic as "quit"
          }
          Ok(uci.EngCmdUCINewGame) -> {
            process.send(robot.subject, robot.Clear)
          }
          Ok(uci.EngCmdIsReady) -> {
            process.send(robot.subject, robot.IsReady)
          }
          Ok(uci.EngCmdPosition(moves:, position:)) -> {
            case position {
              uci.PositionStartPos -> game.start_fen
              uci.PositionFEN(fen) -> fen
            }
            |> robot.SetFen
            |> process.send(robot.subject, _)

            list.each(moves, fn(move) {
              process.send(robot.subject, robot.ApplyMove(move))
            })
          }
          Ok(uci.EngCmdStop) -> {
            process.send(robot.subject, robot.Stop)
          }
          Ok(uci.EngCmdGo(params:)) -> {
            {
              let param_dict =
                list.fold(params, dict.new(), fn(acc, param) {
                  case param {
                    uci.GoParamWTime(time) ->
                      dict.insert(acc, uci.GoParamWTime(0), time)
                    uci.GoParamBTime(time) ->
                      dict.insert(acc, uci.GoParamBTime(0), time)
                    uci.GoParamWInc(time) ->
                      dict.insert(acc, uci.GoParamWInc(0), time)
                    uci.GoParamBInc(time) ->
                      dict.insert(acc, uci.GoParamBInc(0), time)
                    uci.GoParamMoveTime(time) ->
                      dict.insert(acc, uci.GoParamMoveTime(0), time)
                    uci.GoParamInfinite ->
                      dict.insert(acc, uci.GoParamInfinite, 0)
                    uci.GoParamDepth(depth) ->
                      dict.insert(acc, uci.GoParamDepth(0), depth)
                    _ -> panic as { "Go command " <> line <> " has conflicts" }
                  }
                })

              let go_infinite =
                dict.get(param_dict, uci.GoParamInfinite)
                |> result.replace(robot.GoInfinite)
              let go_clock = {
                let x =
                  [
                    uci.GoParamWTime(0),
                    uci.GoParamBTime(0),
                    uci.GoParamWInc(0),
                    uci.GoParamBInc(0),
                  ]
                  |> list.map(dict.get(param_dict, _))
                  |> result.all

                case x {
                  Ok([white_time, black_time, white_increment, black_increment]) ->
                    Ok(robot.GoClock(
                      white_time:,
                      black_time:,
                      white_increment:,
                      black_increment:,
                    ))
                  _ -> Error(Nil)
                }
              }
              let go_general = {
                let assert [movetime, depth] =
                  [uci.GoParamMoveTime(0), uci.GoParamDepth(0)]
                  |> list.map(fn(x) {
                    x |> dict.get(param_dict, _) |> option.from_result
                  })
                Ok(robot.GoGeneral(movetime, depth))
              }

              // Get first matching command
              let assert Ok(msg) =
                [go_infinite, go_clock, go_general]
                |> list.find_map(fn(x) { x })

              msg
            }
            |> process.send(robot.subject, _)
          }
          // We ignore unrecognized commands
          _ -> Nil
        }
      }
      handle_input(robot)
    }
  }
}
