import chess/game
import chess/robot/robot_web
import gleam/erlang/process
import gleam/io
import gleam/result
import gleeunit/should

pub type Timeout {
  Timeout(Float, fn() -> Nil)
}

pub fn search_test_() {
  io.print("ok")
  use <- Timeout(15.0)
  let robot = robot_web.init()
  robot_web.update_fen(
    robot,
    "2k4r/pppq1p1p/8/2b5/3rR1n1/2N5/PPBP1PP1/R1BQ2K1 b - - 1 16",
    [],
  )
  process.sleep(5000)
  robot_web.get_best_move(robot)
  |> result.map(game.move_to_lan)
  |> should.equal(Ok("g4f2"))
}
