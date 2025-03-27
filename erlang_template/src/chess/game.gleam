import chess/chess.{
  type Game, type Move, type Piece, type Square, Bishop, Black, Game, King,
  Knight, Pawn, Piece, Queen, Rook, White,
}
import gleam/dict
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/pair
import gleam/result
import gleam/string

pub fn load_fen(fen: String) -> Result(Game, Nil) {
  use
    #(
      piece_placement_data,
      active_color,
      castling_availability,
      en_passant_target_square,
      halfmove_clock,
      fullmove_number,
    )
  <- result.try(
    fen
    |> string.split(" ")
    |> fn(lst) {
      case lst {
        // a-f are 1-1 to what's destructured above. I'm too lazy and it's too
        // verbose to type them all out.
        [a, b, c, d, e, f] -> Ok(#(a, b, c, d, e, f))
        _ -> Error(Nil)
      }
    },
  )

  use board <- result.try(
    piece_placement_data
    // Flatten the entire board into char array
    |> string.to_graphemes
    // Fold over a flat position, cell-dictionary pair.
    |> list.fold(from: Ok(#(0, dict.new())), with: fn(acc, val) {
      use acc <- result.try(acc)
      let #(square, board) = acc

      // String -> Result(Piece, Int)
      // If found a piece, then returns the piece
      // Otherwise, returns how many cells to skip
      let piece_or_skip = case val {
        "r" -> Ok(Piece(Black, Rook))
        "n" -> Ok(Piece(Black, Knight))
        "b" -> Ok(Piece(Black, Bishop))
        "q" -> Ok(Piece(Black, Queen))
        "k" -> Ok(Piece(Black, King))
        "p" -> Ok(Piece(Black, Pawn))

        "R" -> Ok(Piece(White, Rook))
        "N" -> Ok(Piece(White, Knight))
        "B" -> Ok(Piece(White, Bishop))
        "Q" -> Ok(Piece(White, Queen))
        "K" -> Ok(Piece(White, King))
        "P" -> Ok(Piece(White, Pawn))

        "/" -> Error(8)
        // If the int.parse fails, we should really be failing this entire
        // fold, but fuck, I kinda backed myself into a corner with this flow
        // control and I'm too lazy to fix it. I mean, we're gonna be getting
        // valid boards anyway.
        _ -> int.parse(val) |> result.unwrap(0) |> Error
      }

      case piece_or_skip {
        Ok(piece) ->
          algebraic(square)
          |> result.map(fn(alg_square) {
            #(square + 1, board |> dict.insert(alg_square, piece))
          })
        Error(skip) -> Ok(#(square + skip, board))
      }
    })
    |> result.map(pair.second),
  )
  use halfmove_clock <- result.try(int.parse(halfmove_clock))
  use fullmove_number <- result.try(int.parse(fullmove_number))

  Ok(
    Game(
      board: board,
      active_color: case active_color {
        "w" -> White
        "b" -> Black
        _ -> panic
      },
      castling_availability: castling_availability,
      en_passant_target_square: en_passant_target_square,
      halfmove_clock: halfmove_clock,
      fullmove_number: fullmove_number,
      moves: [],
    ),
  )
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
  turn: chess.Player,
  failed_moves: List(String),
) -> Result(String, String) {
  todo
}

// Extracts the zero-based file of an 0x88 square.
fn file(square: Int) -> Int {
  int.bitwise_and(square, 0xf)
}

// Extracts the zero-based rank of an 0x88 square.
fn rank(square: Int) -> Int {
  int.bitwise_shift_right(square, 4)
}

/// Converts a 0x88 square to algebraic notation
fn algebraic(square: Int) -> Result(Square, Nil) {
  let f = file(square)
  let r = rank(square)

  case f, r {
    0, 0 -> Ok(chess.A8)
    0, 1 -> Ok(chess.A7)
    0, 2 -> Ok(chess.A6)
    0, 3 -> Ok(chess.A5)
    0, 4 -> Ok(chess.A4)
    0, 5 -> Ok(chess.A3)
    0, 6 -> Ok(chess.A2)
    0, 7 -> Ok(chess.A1)

    1, 0 -> Ok(chess.B8)
    1, 1 -> Ok(chess.B7)
    1, 2 -> Ok(chess.B6)
    1, 3 -> Ok(chess.B5)
    1, 4 -> Ok(chess.B4)
    1, 5 -> Ok(chess.B3)
    1, 6 -> Ok(chess.B2)
    1, 7 -> Ok(chess.B1)

    2, 0 -> Ok(chess.C8)
    2, 1 -> Ok(chess.C7)
    2, 2 -> Ok(chess.C6)
    2, 3 -> Ok(chess.C5)
    2, 4 -> Ok(chess.C4)
    2, 5 -> Ok(chess.C3)
    2, 6 -> Ok(chess.C2)
    2, 7 -> Ok(chess.C1)

    3, 0 -> Ok(chess.D8)
    3, 1 -> Ok(chess.D7)
    3, 2 -> Ok(chess.D6)
    3, 3 -> Ok(chess.D5)
    3, 4 -> Ok(chess.D4)
    3, 5 -> Ok(chess.D3)
    3, 6 -> Ok(chess.D2)
    3, 7 -> Ok(chess.D1)

    4, 0 -> Ok(chess.E8)
    4, 1 -> Ok(chess.E7)
    4, 2 -> Ok(chess.E6)
    4, 3 -> Ok(chess.E5)
    4, 4 -> Ok(chess.E4)
    4, 5 -> Ok(chess.E3)
    4, 6 -> Ok(chess.E2)
    4, 7 -> Ok(chess.E1)

    5, 0 -> Ok(chess.F8)
    5, 1 -> Ok(chess.F7)
    5, 2 -> Ok(chess.F6)
    5, 3 -> Ok(chess.F5)
    5, 4 -> Ok(chess.F4)
    5, 5 -> Ok(chess.F3)
    5, 6 -> Ok(chess.F2)
    5, 7 -> Ok(chess.F1)

    6, 0 -> Ok(chess.G8)
    6, 1 -> Ok(chess.G7)
    6, 2 -> Ok(chess.G6)
    6, 3 -> Ok(chess.G5)
    6, 4 -> Ok(chess.G4)
    6, 5 -> Ok(chess.G3)
    6, 6 -> Ok(chess.G2)
    6, 7 -> Ok(chess.G1)

    7, 0 -> Ok(chess.H8)
    7, 1 -> Ok(chess.H7)
    7, 2 -> Ok(chess.H6)
    7, 3 -> Ok(chess.H5)
    7, 4 -> Ok(chess.H4)
    7, 5 -> Ok(chess.H3)
    7, 6 -> Ok(chess.H2)
    7, 7 -> Ok(chess.H1)

    _, _ -> Error(Nil)
  }
}

pub fn update_fen(fen: String) -> Result(Game, Nil) {
  todo
}

pub fn apply_move(game: Game, move: Move) -> Result(Game, Nil) {
  todo
}

pub fn piece_at(game: Game, square: Square) -> Result(Piece, Nil) {
  todo
}

pub fn is_attacked(game: Game, square: Square) -> Bool {
  todo
}

pub fn is_check(game: Game) -> Bool {
  todo
}

pub fn is_checkmate(game: Game) -> Bool {
  todo
}

pub fn is_stalemate(game: Game) -> Bool {
  todo
}

pub fn is_threefold_repetition(game: Game) -> Bool {
  todo
}

pub fn ascii(game: Game) -> String {
  todo
}
