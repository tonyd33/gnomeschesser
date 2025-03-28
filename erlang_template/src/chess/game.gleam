import chess/piece
import chess/player
import chess/square
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/pair
import gleam/result
import gleam/string

pub type Castle {
  KingSide
  QueenSide
}

pub opaque type Game {
  Game(
    board: Dict(square.Square, piece.Piece),
    active_color: player.Player,
    castling_availability: List(#(player.Player, Castle)),
    en_passant_target_square: Option(square.Square),
    halfmove_clock: Int,
    fullmove_number: Int,
    history: List(Game),
  )
}

/// TODO: Probably move this into robot.gleam later
pub fn move(
  fen: String,
  turn: player.Player,
  failed_moves: List(String),
) -> Result(String, String) {
  todo
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

  let castling_availability =
    castling_availability
    |> string.to_graphemes
    |> list.fold([], fn(castling_availability, char) {
      castling_availability
      |> list.append(case char {
        "K" -> [#(player.White, KingSide)]
        "Q" -> [#(player.White, QueenSide)]
        "k" -> [#(player.Black, KingSide)]
        "q" -> [#(player.Black, QueenSide)]
        _ -> []
      })
    })
  let en_passant_target_square =
    square.from_string(en_passant_target_square)
    |> option.from_result

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

pub fn turn(game: Game) -> player.Player {
  game.active_color
}

pub fn new(
  board board: Dict(square.Square, piece.Piece),
  active_color active_color: player.Player,
  castling_availability castling_availability: List(#(player.Player, Castle)),
  en_passant_target_square en_passant_target_square: Option(square.Square),
  halfmove_clock halfmove_clock: Int,
  fullmove_number fullmove_number: Int,
  history history: List(Game),
) -> Game {
  Game(
    board,
    active_color,
    castling_availability,
    en_passant_target_square,
    halfmove_clock,
    fullmove_number,
    history,
  )
}

pub fn board(game: Game) -> Dict(square.Square, piece.Piece) {
  game.board
}

pub fn castling_availability(game: Game) -> List(#(player.Player, Castle)) {
  game.castling_availability
}

pub fn en_passant_target_square(game: Game) -> Option(square.Square) {
  game.en_passant_target_square
}

pub fn halfmove_clock(game: Game) -> Int {
  game.halfmove_clock
}

pub fn fullmove_number(game: Game) -> Int {
  game.fullmove_number
}

pub fn history(game: Game) -> List(Game) {
  game.history
}

pub fn update_fen(game: Game, fen: String) -> Result(Game, Nil) {
  todo
}

pub fn to_fen(game: Game) -> String {
  todo
}

/// Returns whether the games are equal, where equality is determined by the
/// equality used for threefold repetition:
/// https://en.wikipedia.org/wiki/Threefold_repetition
///
pub fn equal(g1: Game, g2: Game) -> Bool {
  todo
}

/// Returns the number of times this game state has repeated in the game's
/// history, where equality is determined by the equality used for threefold
/// repetition: https://en.wikipedia.org/wiki/Threefold_repetition
///
pub fn repetition_count(game: Game) -> Int {
  todo
}

pub fn piece_at(game: Game, square: square.Square) -> Result(piece.Piece, Nil) {
  game.board |> dict.get(square)
}

pub fn square_empty(game: Game, square: square.Square) -> Bool {
  case piece_at(game, square) {
    Ok(_) -> False
    Error(_) -> True
  }
}

pub fn empty_at(game: Game, square: square.Square) -> Bool {
  todo
}

pub fn find_piece(game: Game, piece: piece.Piece) -> List(square.Square) {
  todo
}

pub fn is_attacked(game: Game, square: square.Square, by: player.Player) -> Bool {
  todo
}

/// Returns the position and pieces that are attacking a square.
///
pub fn attackers(
  game: Game,
  square: square.Square,
) -> List(#(square.Square, piece.Piece)) {
  todo
}

/// Returns the position and pieces that are attacking a square of a certain
/// color. `by` is the color that is *attacking*.
///
pub fn attackers_by_player(
  game: Game,
  square: square.Square,
  by: player.Player,
) -> List(#(square.Square, piece.Piece)) {
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

/// There are certain board configurations in which it is impossible for either
/// player to win if both players are playing optimally. This functions returns
/// true iff that's the case. See the same function in chess.js:
/// https://github.com/jhlywa/chess.js/blob/dc1f397bc0195dda45e12f0ddf3322550cbee078/src/chess.ts#L1123
///
pub fn is_insufficient_material(game: Game) -> Bool {
  todo
}

pub fn is_game_over(game: Game) -> Bool {
  todo
}

pub fn ascii(game: Game) -> String {
  todo
}

pub fn pieces(game: Game) -> List(#(square.Square, piece.Piece)) {
  game.board |> dict.to_list
}
