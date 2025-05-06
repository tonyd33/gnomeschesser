import chess/game
import chess/robot/robot_uci as robot
import chess/uci
import gleam/bool
import gleam/dict
import gleam/erlang
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import util/parser.{type Parser} as p

pub fn start_robot() -> Nil {
  let robot = robot.init()
  process.start(fn() { handle_input(robot) }, True)
  Nil
}

fn handle_input(robot: robot.Robot) {
  //serialize_gui_cmd
  let engine_cmd = uci.engine_cmd()
  case erlang.get_line("") {
    Error(erlang.Eof) -> Nil

    Error(erlang.NoData) -> Nil

    Ok(line) -> {
      io.print_error("received: " <> line)
      {
        let parsed = p.run(engine_cmd, line)
        // TODO: I forgot how to do this without bool.guard

        case parsed {
          Ok(uci.EngCmdUCI) -> process.send(robot.subject, robot.UciStart)
          Ok(uci.EngCmdQuit) -> process.send(robot.subject, robot.Kill)
          Ok(uci.EngCmdUCINewGame) -> process.send(robot.subject, robot.Clear)
          Ok(uci.EngCmdIsReady) -> process.send(robot.subject, robot.IsReady)
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
          Ok(uci.EngCmdStop) -> process.send(robot.subject, robot.Stop)
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
                    _ -> panic as { "Go command " <> line <> " has conflicts" }
                  }
                })

              use <- result.lazy_unwrap(
                dict.get(param_dict, uci.GoParamInfinite)
                |> result.replace(robot.GoInfinite),
              )

              use <- result.lazy_unwrap(
                dict.get(param_dict, uci.GoParamMoveTime(0))
                |> result.map(robot.GoMoveTime),
              )
              case
                dict.get(param_dict, uci.GoParamWTime(0)),
                dict.get(param_dict, uci.GoParamBTime(0)),
                dict.get(param_dict, uci.GoParamWInc(0)),
                dict.get(param_dict, uci.GoParamBInc(0))
              {
                Ok(white_time),
                  Ok(black_time),
                  Ok(white_increment),
                  Ok(black_increment)
                ->
                  robot.GoClock(
                    white_time:,
                    black_time:,
                    white_increment:,
                    black_increment:,
                  )
                _, _, _, _ ->
                  panic as {
                    "go command " <> line <> "does not have valid arguments"
                  }
              }
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
