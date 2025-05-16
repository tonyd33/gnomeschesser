import chess/move
import chess/robot/robot_web
import gleam/erlang/process
import gleam/result
import gleeunit/should

pub type Timeout {
  Timeout(Float, fn() -> Nil)
}

pub fn robot_web_test_() {
  use <- Timeout(15.0)
  let robot = robot_web.init()
  robot_web.update_fen(
    robot,
    "2k4r/pppq1p1p/8/2b5/3rR1n1/2N5/PPBP1PP1/R1BQ2K1 b - - 1 16",
    [],
  )
  process.sleep(500)
  robot_web.get_best_move(robot)
  |> result.map(move.to_lan)
  |> should.equal(Ok("g4f2"))
}

pub fn robot_mating_position_test_() {
  use <- Timeout(15.0)
  let robot = robot_web.init()

  robot_web.get_best_move_from_fen_by(
    robot,
    "1k6/ppppp3/ppppp3/8/8/8/8/K6R w - - 0 1",
    500,
  )
  |> result.map(move.to_lan)
  |> should.equal(Ok("h1h8"))
}
