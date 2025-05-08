// For diagonals simply use a combination of these
pub type Direction {
  Up
  Down
  Left
  Right
}

pub fn opposite(dir: Direction) -> Direction {
  case dir {
    Up -> Down
    Down -> Up
    Left -> Right
    Right -> Left
  }
}
