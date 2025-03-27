import chess/piece
import chess/player
import chess/square
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/pair
import gleam/result
import gleam/string

pub type Castle {
  KingSide
  QueenSide
}

pub type Game {
  Game(
    board: Dict(square.Square, piece.Piece),
    active_color: player.Player,
    // TODO: Change to List(#(Player, Castle))
    castling_availability: String,
    // TODO: Change into Square
    en_passant_target_square: String,
    halfmove_clock: Int,
    fullmove_number: Int,
    // TODO: Possibly don't need this
    history: List(Game),
  )
}

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
        "r" -> Ok(piece.Piece(player.Black, piece.Rook))
        "n" -> Ok(piece.Piece(player.Black, piece.Knight))
        "b" -> Ok(piece.Piece(player.Black, piece.Bishop))
        "q" -> Ok(piece.Piece(player.Black, piece.Queen))
        "k" -> Ok(piece.Piece(player.Black, piece.King))
        "p" -> Ok(piece.Piece(player.Black, piece.Pawn))

        "R" -> Ok(piece.Piece(player.White, piece.Rook))
        "N" -> Ok(piece.Piece(player.White, piece.Knight))
        "B" -> Ok(piece.Piece(player.White, piece.Bishop))
        "Q" -> Ok(piece.Piece(player.White, piece.Queen))
        "K" -> Ok(piece.Piece(player.White, piece.King))
        "P" -> Ok(piece.Piece(player.White, piece.Pawn))

        "/" -> Error(8)
        // If the int.parse fails, we should really be failing this entire
        // fold, but fuck, I kinda backed myself into a corner with this flow
        // control and I'm too lazy to fix it. I mean, we're gonna be getting
        // valid boards anyway.
        _ -> int.parse(val) |> result.unwrap(0) |> Error
      }

      case piece_or_skip {
        Ok(piece) ->
          square.algebraic(square)
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
        "w" -> player.White
        "b" -> player.Black
        _ -> panic
      },
      castling_availability: castling_availability,
      en_passant_target_square: en_passant_target_square,
      halfmove_clock: halfmove_clock,
      fullmove_number: fullmove_number,
      history: [],
    ),
  )
}

pub fn player_decoder() {
  use player_string <- decode.then(decode.string)
  case player_string {
    "white" -> decode.success(player.White)
    "black" -> decode.success(player.Black)
    _ -> decode.failure(player.White, "Invalid player")
  }
}

pub fn move(
  fen: String,
  turn: player.Player,
  failed_moves: List(String),
) -> Result(String, String) {
  todo
}

pub fn update_fen(fen: String) -> Result(Game, Nil) {
  todo
}

pub fn piece_at(game: Game, square: square.Square) -> Result(piece.Piece, Nil) {
  todo
}

pub fn is_attacked(game: Game, square: square.Square) -> Bool {
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
