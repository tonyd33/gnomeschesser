import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/string

pub type Player {
  White
  Black
}

// TODO: Reorganize symbols
pub type Piece {
  Pawn
  Knight
  Bishop
  Rook
  Queen
  King
}

pub type Position =
  #(Int, Int)

pub type Board {
  Board(cells: Dict(Position, #(Piece, Player)))
}

pub type Game {
  Game(board: Board)
}

pub fn result_expect(result: Result(a, b)) -> a {
  case result {
    Ok(a) -> a
    _ -> panic
  }
}

pub fn fen_to_game(fen: String) -> Game {
  let assert [
    piece_placement_data,
    active_color,
    castling_availability,
    en_passant_target_square,
    halfmove_clock,
    fullmove_number,
  ] =
    fen
    |> string.split(" ")

  let board =
    piece_placement_data
    // Flatten the entire board into char array
    |> string.split("/")
    |> list.map(string.to_graphemes)
    |> list.flatten
    // Fold over a flat position, cell-dictionary pair.
    // Start at flat position 0 (a8)
    |> list.fold(from: #(0, dict.new()), with: fn(acc, val) {
      let #(position_flat, cells) = acc
      let position_2d = #(position_flat % 8, 7 - { position_flat / 8 })

      // String -> Result(#(Piece, Player), Int)
      // If found a piece, then returns the piece and owned by who
      // Otherwise, returns how many cells to skip
      let piece_or_skip = case val {
        "r" -> Ok(#(Rook, Black))
        "n" -> Ok(#(Knight, Black))
        "b" -> Ok(#(Bishop, Black))
        "q" -> Ok(#(Queen, Black))
        "k" -> Ok(#(King, Black))
        "p" -> Ok(#(Pawn, Black))

        "R" -> Ok(#(Rook, White))
        "N" -> Ok(#(Knight, White))
        "B" -> Ok(#(Bishop, White))
        "Q" -> Ok(#(Queen, White))
        "K" -> Ok(#(King, White))
        "P" -> Ok(#(Pawn, White))

        _ -> int.parse(val) |> result_expect |> Error
      }

      case piece_or_skip {
        Ok(piece) -> #(
          position_flat + 1,
          cells |> dict.insert(position_2d, piece),
        )
        Error(skip) -> #(position_flat + skip, cells)
      }
    })
    |> fn(x) { Board(cells: x.1) }

  Game(board: board)
}

pub fn player_decoder() {
  use player_string <- decode.then(decode.string)
  case player_string {
    "white" -> decode.success(White)
    "black" -> decode.success(Black)
    _ -> decode.failure(White, "Invalid player")
  }
}

pub fn move(
  fen: String,
  turn: Player,
  failed_moves: List(String),
) -> Result(String, String) {
  todo
}
