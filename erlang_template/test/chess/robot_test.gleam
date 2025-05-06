import chess/robot
import gleeunit/should

pub type Timeout {
  Timeout(Float, fn() -> Nil)
}

pub fn search_test_() {
  use <- Timeout(5.0)
  let robot = robot.init()
  robot.update_fen(
    robot,
    "2k4r/pppq1p1p/8/2b5/3rR1n1/2N5/PPBP1PP1/R1BQ2K1 b - - 1 16",
    [],
  )
  robot.get_best_move_after(robot, 4950)
  |> should.equal(Ok("Nxf2"))
}
