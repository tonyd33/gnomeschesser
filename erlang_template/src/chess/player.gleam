import gleam/dynamic/decode
import util/direction

pub type Player {
  White
  Black
}

pub fn player_decoder() {
  use player_string <- decode.then(decode.string)
  case player_string {
    "white" -> decode.success(White)
    "black" -> decode.success(Black)
    _ -> decode.failure(White, "Invalid player")
  }
}

pub fn opponent(player: Player) -> Player {
  case player {
    White -> Black
    Black -> White
  }
}

pub fn direction(player: Player) -> direction.Direction {
  case player {
    White -> direction.Up
    Black -> direction.Down
  }
}
