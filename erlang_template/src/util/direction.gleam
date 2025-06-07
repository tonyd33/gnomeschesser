/// Denotes a direction on the chess board, from white's sitting perspective
/// For diagonals simply use a combination of these
pub type Direction {
  Up
  UpRight
  Right
  DownRight
  Down
  DownLeft
  Left
  UpLeft
}

pub fn opposite(dir: Direction) -> Direction {
  case dir {
    Up -> Down
    UpRight -> DownLeft
    Right -> Left
    DownRight -> UpLeft
    Down -> Up
    DownLeft -> UpRight
    Left -> Right
    UpLeft -> DownRight
  }
}

pub fn number(dir: Direction) -> Int {
  case dir {
    Up -> 0
    UpRight -> 1
    Right -> 2
    DownRight -> 3
    Down -> 4
    DownLeft -> 5
    Left -> 6
    UpLeft -> 7
  }
}
