/// Denotes a direction on the chess board, from white's sitting perspective
/// For diagonals simply use a combination of these
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
