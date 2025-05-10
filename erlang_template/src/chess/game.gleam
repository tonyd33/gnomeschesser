import chess/bitboard
import chess/game/castle.{type Castle, KingSide, QueenSide}
import chess/move
import chess/move/disambiguation
import chess/piece
import chess/player
import chess/square
import gleam/bool
import gleam/dict.{type Dict}
import gleam/function
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/pair
import gleam/result
import gleam/string
import util/direction

pub const start_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

pub opaque type Game {
  Game(
    board: Dict(square.Square, piece.Piece),
    bitboard: bitboard.GameBitboard,
    attacking: bitboard.GameBitboard,
    active_color: player.Player,
    castling_availability: List(#(player.Player, Castle)),
    en_passant_target_square: Option(#(player.Player, square.Square)),
    halfmove_clock: Int,
    fullmove_number: Int,
  )
}

pub fn get_game_bitboard(game: Game) {
  game.bitboard
}

pub fn get_attacking_bitboard(game: Game) {
  game.attacking
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

  let pieces =
    {
      string.split(piece_placement_data, "/")
      |> list.strict_zip(list.range(7, 0))
    }
    |> result.try(fn(x) {
      list.flat_map(x, fn(x) {
        let #(piece_placements, rank) = x

        let #(_, pieces) =
          string.to_graphemes(piece_placements)
          |> list.fold(from: #(0, []), with: fn(acc, contents) {
            let #(file, pieces) = acc

            let piece_symbol = case contents |> string.lowercase {
              "r" -> Some(piece.Rook)
              "n" -> Some(piece.Knight)
              "b" -> Some(piece.Bishop)
              "q" -> Some(piece.Queen)
              "k" -> Some(piece.King)
              "p" -> Some(piece.Pawn)
              _ -> None
            }

            option.map(piece_symbol, fn(piece_symbol) {
              let square = square.from_rank_file(rank, file)
              let player = case contents == string.lowercase(contents) {
                True -> player.Black
                False -> player.White
              }
              let new_piece =
                result.map(square, pair.new(
                  _,
                  piece.Piece(player, piece_symbol),
                ))
              #(file + 1, [new_piece, ..pieces])
            })
            |> option.lazy_unwrap(fn() {
              let advance = int.parse(contents) |> result.unwrap(0)
              #(file + advance, pieces)
            })
          })
        pieces
      })
      |> result.all
    })

  use pieces <- result.try(pieces)
  let board = dict.from_list(pieces)
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

  let active_color = case active_color {
    "w" -> player.White
    "b" -> player.Black
    _ -> panic
  }
  let en_passant_target_square =
    square.from_string(en_passant_target_square)
    |> result.map(pair.new(active_color, _))
    |> option.from_result
  let bitboard = bitboard.from_pieces(pieces)
  let game =
    Game(
      board:,
      bitboard:,
      attacking: bitboard.GameBitboard(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
      active_color:,
      castling_availability:,
      en_passant_target_square:,
      halfmove_clock:,
      fullmove_number:,
    )
  Game(..game, attacking: generate_attacking_bitboard(game))
  |> Ok
}

pub fn turn(game: Game) -> player.Player {
  game.active_color
}

pub fn board(game: Game) -> Dict(square.Square, piece.Piece) {
  game.board
}

pub fn castling_availability(game: Game) -> List(#(player.Player, Castle)) {
  game.castling_availability
}

pub fn en_passant_target_square(
  game: Game,
) -> Option(#(player.Player, square.Square)) {
  game.en_passant_target_square
}

pub fn halfmove_clock(game: Game) -> Int {
  game.halfmove_clock
}

pub fn fullmove_number(game: Game) -> Int {
  game.fullmove_number
}

pub fn to_fen(game: Game) -> String {
  // todo: board positions

  let ranks = [8, 7, 6, 5, 4, 3, 2, 1]
  let files = ["a", "b", "c", "d", "e", "f", "g", "h"]

  let piece_placement =
    ranks
    |> list.map(fn(rank) {
      list.map(files, fn(file) {
        let actual_square =
          square.from_string(file <> int.to_string(rank))
          |> result.lazy_unwrap(fn() {
            panic as "This isn't supposed to happen"
          })

        let _piece_string = case dict.has_key(game.board, actual_square) {
          True -> {
            dict.get(game.board, actual_square)
            |> result.lazy_unwrap(fn() {
              panic as "This isn't supposed to happen"
            })
            |> piece.to_string()
          }
          False -> ""
        }
      })
      |> list.fold(#("", 0), fn(acc, val) {
        let #(curr_string, num_empty) = acc
        case val {
          "" -> #(curr_string, num_empty + 1)
          _ -> {
            case num_empty {
              0 -> #(curr_string <> val, 0)
              _ -> #(curr_string <> int.to_string(num_empty) <> val, 0)
            }
          }
        }
      })
      |> fn(x) {
        case x.1 {
          0 -> x.0
          _ -> x.0 <> int.to_string(x.1)
        }
      }
    })
    |> string.join("/")

  let halfmove_clock_string = int.to_string(game.halfmove_clock)
  let fullmove_number_string = int.to_string(game.fullmove_number)
  let castling_rights_string =
    game.castling_availability
    |> list.filter_map(fn(val) {
      case val {
        #(player.White, KingSide) -> Ok("K")
        #(player.White, QueenSide) -> Ok("Q")
        #(player.Black, KingSide) -> Ok("k")
        #(player.Black, QueenSide) -> Ok("q")
      }
    })
    |> fn(rights) {
      case rights {
        [] -> "-"
        _ -> list.fold(rights, "", fn(str, val) { str <> val })
      }
    }
  let active_color_string = case game.active_color {
    player.Black -> "b"
    player.White -> "w"
  }

  let en_passant_target_string = case game.en_passant_target_square {
    option.Some(#(_, target_square)) -> square.to_string(target_square)
    option.None -> "-"
  }

  string.join(
    [
      piece_placement,
      active_color_string,
      castling_rights_string,
      en_passant_target_string,
      halfmove_clock_string,
      fullmove_number_string,
    ],
    " ",
  )
}

/// Returns whether the games are equal, where equality is determined by the
/// equality used for threefold repetition:
/// https://en.wikipedia.org/wiki/Threefold_repetition
///
/// TODO: use zobrist once we generate it for every game
pub fn equal(g1: Game, g2: Game) -> Bool {
  let g1_fen = to_fen(g1)
  let g2_fen = to_fen(g2)
  list.take(string.split(g1_fen, " "), 4)
  == list.take(string.split(g2_fen, " "), 4)
}

pub fn piece_at(game: Game, square: square.Square) -> Result(piece.Piece, Nil) {
  game.board |> dict.get(square)
}

pub fn empty_at(game: Game, square: square.Square) -> Bool {
  let square = bitboard.from_square(square)
  0 == int.bitwise_and(square, bitboard.get_bitboard_all(game.bitboard))
}

pub fn find_piece(game: Game, piece: piece.Piece) -> List(square.Square) {
  dict.filter(game.board, fn(_, p) { p == piece })
  |> dict.keys()
}

pub fn is_attacked(
  game: Game,
  bitboard: bitboard.BitBoard,
  by by: player.Player,
) -> Bool {
  int.bitwise_and(bitboard.get_bitboard_player(game.attacking, by), bitboard)
  != 0
}

/// Gets the actual captured square (if there's a valid source)
/// checks the en-passant square + pawn moves
/// Does NOT check if the game's side is valid
fn move_capture_square(
  move: move.Move(a),
  game: Game,
) -> Result(square.Square, Nil) {
  let from = move.get_from(move)
  let to = move.get_to(move)
  use piece <- result.try(piece_at(game, from))
  case piece {
    piece.Piece(side, piece.Pawn) -> {
      // return error if pawn move isn't a diagonal
      use <- bool.guard(square.file(from) == square.file(to), Error(Nil))
      let other_side = player.opponent(side)
      // If it's not an en-passant move, just return the target square
      use <- bool.guard(
        game.en_passant_target_square != Some(#(other_side, to)),
        Ok(to),
      )
      // if it is an en passant move, the capture square is backwards one
      let assert Ok(square) =
        player.direction(side)
        |> direction.opposite
        |> square.move(to, _, 1)
      Ok(square)
    }
    _ -> Ok(to)
  }
}

fn generate_attacking_bitboard(game: Game) -> bitboard.GameBitboard {
  let to_square_pieces = fn(move) {
    use capture_square <- result.map(move_capture_square(move, game))
    let from = move.get_from(move)
    let assert Ok(piece) = piece_at(game, from)
    #(capture_square, piece)
  }
  let white_moves =
    pseudo_moves_player(game, player.White)
    |> list.filter_map(to_square_pieces)
  let black_moves =
    pseudo_moves_player(game, player.Black)
    |> list.filter_map(to_square_pieces)

  bitboard.from_pieces(list.flatten([white_moves, black_moves]))
}

pub fn is_check(game: Game, player: player.Player) -> Bool {
  bitboard.get_bitboard_piece(game.bitboard, piece.Piece(player, piece.King))
  |> is_attacked(game, _, player.opponent(player))
}

pub fn is_checkmate(game: Game) -> Bool {
  let us = turn(game)
  is_check(game, us)
  && {
    pseudo_moves(game)
    |> list.all(fn(x) {
      // If every new move we try still result in a check, then it's checkmate
      case apply(game, x) {
        Ok(#(game, _move)) -> is_check(game, us)
        Error(Nil) -> True
      }
    })
  }
}

pub fn is_stalemate(game: Game) -> Bool {
  !is_check(game, game.active_color)
  && {
    pseudo_moves(game)
    |> list.filter(fn(x) { apply(game, x) |> result.is_ok })
    |> list.is_empty
  }
}

/// There are certain board configurations in which it is impossible for either
/// player to win if both players are playing optimally. This functions returns
/// true iff that's the case. See the same function in chess.js:
/// https://github.com/jhlywa/chess.js/blob/dc1f397bc0195dda45e12f0ddf3322550cbee078/src/chess.ts#L1123
///
pub fn is_insufficient_material(_game: Game) -> Bool {
  todo
}

pub fn is_draw(_game: Game) -> Bool {
  False
}

pub fn is_game_over(game: Game) -> Bool {
  is_checkmate(game) || is_stalemate(game) || is_draw(game)
}

pub fn ascii(game: Game) -> String {
  [
    ["   +------------------------+"],
    {
      list.map(list.range(7, 0), fn(rank) {
        " "
        <> int.to_string(rank + 1)
        <> " |"
        <> string.concat(
          list.map(list.range(0, 7), fn(file) {
            let assert Ok(square) = square.from_rank_file(rank, file)
            case dict.get(game.board, square) {
              Ok(piece) -> " " <> piece.to_string(piece) <> " "
              _ -> " . "
            }
          }),
        )
        <> "|"
      })
    },
    ["   +------------------------+"],
    ["     a  b  c  d  e  f  g  h"],
  ]
  |> list.flatten
  |> string.join("\n")
}

pub fn pieces(game: Game) -> List(#(square.Square, piece.Piece)) {
  game.board |> dict.to_list
}

// There are functions that require the game state as well as move, those will go here
/// Standard Algebraic Notation
/// https://en.wikipedia.org/wiki/Algebraic_notation_(chess)
///
pub type SAN =
  String

/// Convert a move to SAN.
/// *This is expensive, so use it sparingly.*
///
pub fn move_to_san(move: move.Move(a), game: Game) -> Result(SAN, Nil) {
  let us = game.active_color
  let them = player.opponent(us)
  let from = move.get_from(move)
  let to = move.get_to(move)
  let assert Ok(us_piece) = dict.get(game.board, from)
  use #(new_game, move) <- result.try(apply(game, move))
  // no moving if we're in check
  use <- bool.guard(is_check(new_game, us), Error(Nil))

  // We can assume `move` is legal from this point on

  // Calculate castle moves
  let castle_san = case us_piece {
    piece.Piece(side, piece.King) -> {
      use <- bool.guard(
        move.equal(move, castle.king_move(side, KingSide)),
        Ok("O-O"),
      )
      use <- bool.guard(
        move.equal(move, castle.king_move(side, QueenSide)),
        Ok("O-O-O"),
      )
      Error(Nil)
    }
    _ -> Error(Nil)
  }
  use <- result.lazy_or(castle_san)
  // use <- result.lazy_unwrap(castle_san)

  let undecorated_san = {
    let is_capture =
      dict.get(game.board, to)
      |> result.map(fn(x) { x.player == them })
      |> result.unwrap(False)

    // Calculate pawn moves
    let pawn_san = {
      use <- bool.guard(us_piece.symbol != piece.Pawn, Error(Nil))
      let is_capture =
        is_capture || Some(#(them, to)) == game.en_passant_target_square
      Ok(
        case is_capture {
          True -> square.file_to_string(square.file(from)) <> "x"
          False -> ""
        }
        <> square.to_string(to)
        <> case move.get_promotion(move) {
          Some(piece) -> "=" <> piece.symbol_to_string(piece)
          None -> ""
        },
      )
    }
    use <- result.lazy_unwrap(pawn_san)

    // calculate all other moves
    let _other_san = {
      let other_ambiguous_moves =
        // find other pseudo_moves that have the same player and piece type that's targeting
        // don't include ourselves
        pseudo_moves(game)
        |> list.filter(fn(other_move) {
          move.get_to(other_move) == to
          && !move.equal(move, other_move)
          && { dict.get(game.board, move.get_from(other_move)) == Ok(us_piece) }
        })

      piece.symbol_to_string(us_piece.symbol)
      <> {
        // handle disambiguation here
        let ambiguity =
          list.fold(
            other_ambiguous_moves,
            disambiguation.Unambiguous,
            fn(ambiguity, other_move) {
              let other_from = move.get_from(other_move)
              // Skip invalid moves here
              // check if it's the same type of piece
              // check if the move is even valid
              use <- bool.guard(
                move.get_to(other_move) != to
                  || move.equal(move, other_move)
                  || piece_at(game, other_from) != Ok(us_piece)
                  || result.is_error(apply(game, other_move)),
                ambiguity,
              )
              let same_file = square.file(from) == square.file(other_from)
              let same_rank = square.rank(from) == square.rank(other_from)
              case same_file, same_rank {
                False, False -> disambiguation.GenerallyAmbiguous
                False, True -> disambiguation.Rank
                True, False -> disambiguation.File
                True, True -> disambiguation.Unambiguous
              }
              |> disambiguation.add(ambiguity)
            },
          )
        case ambiguity {
          disambiguation.Unambiguous -> ""
          disambiguation.Rank | disambiguation.GenerallyAmbiguous ->
            square.file_to_string(square.file(from))
          disambiguation.File -> square.rank_to_string(square.rank(from))
          disambiguation.Both -> square.to_string(from)
        }
      }
      <> case is_capture {
        True -> "x"
        False -> ""
      }
      <> square.to_string(to)
    }
  }
  Ok(
    undecorated_san
    <> case is_check(new_game, them), is_checkmate(new_game) {
      _, True -> "#"
      True, _ -> "+"
      _, _ -> ""
    },
  )
}

/// Create a move from a SAN. The SAN must be strictly valid, including
/// disambiguation only when necessary, captures, check/checkmates, etc.
/// TODO: Possibly allow more flexibility
/// TODO: generate this in a way that doesn't involve generating every move
/// 
pub fn move_from_san(
  san: String,
  game: Game,
) -> Result(move.Move(move.Pseudo), Nil) {
  pseudo_moves(game)
  |> list.find(fn(x) { move_to_san(x, game) == Ok(san) })
}

/// Applies a move to a game, takes either pseudo or validated moves
/// Returns a validated version of the move
/// TODO: we could return the new validated move?
pub fn apply(
  game: Game,
  move: move.Move(a),
) -> Result(#(Game, move.Move(move.ValidInContext)), Nil) {
  let from = move.get_from(move)
  let to = move.get_to(move)
  let promotion = move.get_promotion(move)
  let Game(
    board:,
    bitboard:,
    attacking:,
    castling_availability:,
    active_color: us,
    en_passant_target_square: _,
    fullmove_number:,
    halfmove_clock:,
  ) = game
  let them = player.opponent(us)
  use piece <- result.try(dict.get(board, from))

  // Return early if trying to move non-active player
  use <- bool.guard(piece.player != us, Error(Nil))

  // Get capture square and potential piece
  let captured_square = move_capture_square(move, game)
  let captured_piece = result.try(captured_square, dict.get(board, _))

  // If it's a pawn move that's trying to capture
  // there needs to be a piece actually there or it can't move
  // (unlike all other pieces)
  use <- bool.guard(
    piece.symbol == piece.Pawn
      && square.file(from) != square.file(to)
      && result.is_error(captured_piece),
    Error(Nil),
  )

  // castle update, the king move is handled by the regular move logic
  use #(board, bitboard, castling_availability) <- result.try({
    let king_from_file = square.file(from)
    let king_to_file = square.file(to)
    use <- bool.guard(
      piece.symbol != piece.King
        || int.absolute_value(king_from_file - king_to_file) <= 1,
      // not a castle attempt
      #(board, bitboard, castling_availability) |> Ok,
    )

    let castle_type = case int.compare(king_from_file, king_to_file) {
      order.Gt -> castle.QueenSide
      order.Lt -> castle.KingSide
      order.Eq -> panic
    }

    // The rook's position in this game will not change whether they have a check here
    // We'll also assume that the king's position on the board won't change the check 
    let attacked =
      castle.unattacked_bitboard(us, castle_type)
      |> is_attacked(game, _, by: them)
    use <- bool.guard(attacked, Error(Nil))

    // Handle rook teleportation now
    let rook_move = castle.rook_move(us, castle_type)
    let rook_piece = piece.Piece(us, piece.Rook)
    let board =
      dict.delete(board, move.get_from(rook_move))
      |> dict.insert(move.get_to(rook_move), rook_piece)
    let bitboard =
      bitboard.exclusive_or(
        bitboard,
        rook_piece,
        int.bitwise_or(bitboard.from_square(from), bitboard.from_square(to)),
      )

    let castling_availability =
      list.filter(castling_availability, fn(x) { x.0 != us })
    #(board, bitboard, castling_availability) |> Ok
  })

  // update castling availibility based on new game state
  let castling_availability = {
    let kingside_rook_file = castle.rook_from_file(castle.KingSide)
    let queenside_rook_file = castle.rook_from_file(castle.QueenSide)
    // if we capture a rook in their home square, remove their availability
    let capture_removal =
      {
        use captured_piece <- result.map(captured_piece)
        let assert Ok(captured_square) = captured_square

        case captured_piece, captured_square |> square.file {
          piece.Piece(side, piece.Rook), file if file == kingside_rook_file -> [
            #(side, castle.KingSide),
          ]
          piece.Piece(side, piece.Rook), file if file == queenside_rook_file -> [
            #(side, castle.QueenSide),
          ]
          _, _ -> []
        }
      }
      |> result.unwrap([])
    // if we move a king or a rook, remove availablity
    let move_removal = case piece.symbol {
      piece.King -> [#(us, castle.KingSide), #(us, castle.QueenSide)]
      piece.Rook -> {
        case square.file(from) {
          from_file if from_file == kingside_rook_file -> [
            #(us, castle.KingSide),
          ]

          from_file if from_file == queenside_rook_file -> [
            #(us, castle.QueenSide),
          ]
          _ -> []
        }
      }
      _ -> []
    }
    let removals = list.flatten([capture_removal, move_removal])
    list.filter(castling_availability, fn(x) { !list.contains(removals, x) })
  }

  // en passant target square update
  // if it's a pawn move and it has a 2 rank difference
  let en_passant_target_square = case piece.symbol {
    piece.Pawn ->
      case int.absolute_value(square.rank(from) - square.rank(to)) {
        2 -> {
          let assert Ok(square) =
            case us {
              player.White -> direction.Up
              player.Black -> direction.Down
            }
            |> square.move(from, _, 1)
          Some(#(us, square))
        }
        _ -> None
      }
    _ -> None
  }

  // update the piece if it's a promotion
  let new_piece =
    promotion |> option.map(piece.Piece(us, _)) |> option.unwrap(piece)
  // board update
  let board =
    dict.delete(board, from)
    // captured square might be different from actual square due to en passant
    |> case captured_square {
      Ok(captured_square) -> dict.delete(_, captured_square)
      _ -> function.identity
    }
    |> dict.insert(to, new_piece)

  // bitboard update
  let bitboard =
    bitboard
    // mask out the from square
    |> bitboard.and(piece, int.bitwise_not(bitboard.from_square(from)))
    // mask in the to square 
    |> bitboard.or(new_piece, bitboard.from_square(to))
    // mask out the captured square if it exists
    |> case captured_piece, captured_square {
      Ok(captured_piece), Ok(captured_square) -> bitboard.and(
        _,
        captured_piece,
        int.bitwise_not(bitboard.from_square(captured_square)),
      )
      _, _ -> function.identity
    }

  let fullmove_number = case us {
    player.Black -> fullmove_number + 1
    player.White -> fullmove_number
  }
  let halfmove_clock = case piece.symbol, captured_piece {
    piece.Pawn, _ | _, Ok(_) -> 0
    _, _ -> halfmove_clock + 1
  }

  let game =
    Game(
      board:,
      bitboard:,
      attacking:,
      active_color: them,
      castling_availability:,
      en_passant_target_square:,
      fullmove_number:,
      halfmove_clock:,
    )
  let game = Game(..game, attacking: generate_attacking_bitboard(game))

  // We need to verify that we're not in check here
  use <- bool.guard(is_check(game, us), Error(Nil))

  let validated_move = {
    let capture = result.is_ok(captured_piece)

    let context =
      move.Context(
        capture:,
        player: piece.player,
        // Make sure we're using the pre-promotion piece!
        piece: piece.symbol,
      )
      |> Some
    move.new_valid(from:, to:, promotion:, context:)
  }
  #(game, validated_move)
  |> Ok
}

/// Generate moves that don't care about checks
/// It only ensures that moves are moving into unoccupied space (or a capture)
/// And also that castles aren't occupied by pieces
/// but it does not check if there's an attack in the way
pub fn pseudo_moves(game: Game) -> List(move.Move(move.Pseudo)) {
  pseudo_moves_player(game, game.active_color)
}

pub fn pseudo_moves_player(
  game: Game,
  player: player.Player,
) -> List(move.Move(move.Pseudo)) {
  let us = player
  let us_bitboard = bitboard.get_bitboard_player(game.bitboard, us)
  let all_bitboard = bitboard.get_bitboard_all(game.bitboard)
  let us_pieces_list =
    game.board
    |> dict.to_list
    |> list.filter(fn(square_piece) { { square_piece.1 }.player == us })

  let #(pawn_moves_one, pawn_moves_two, pawn_moves_captures) = {
    let pawn_bb =
      bitboard.get_bitboard_piece(game.bitboard, piece.Piece(us, piece.Pawn))

    // The direction that our pawns travel
    let us_direction = case us {
      player.White -> direction.Up
      player.Black -> direction.Down
    }
    let their_direction = direction.opposite(us_direction)

    let promotions = fn(to: square.Square) {
      case square.rank(to) == square.pawn_promotion_rank(us) {
        True -> [
          Some(piece.Rook),
          Some(piece.Bishop),
          Some(piece.Knight),
          Some(piece.Queen),
        ]
        False -> [None]
      }
    }
    let one_move =
      pawn_bb
      // advance the entire bitboard according to pawn direction
      |> bitboard.move(us_direction, 1)
      // we mask the positions that we're trying to move to that also
      // doesn't have a piece there
      |> int.bitwise_and(int.bitwise_not(all_bitboard))
      |> bitboard.to_squares
      |> list.flat_map(fn(to) {
        // move backwards to find our previous position
        let assert Ok(from) = square.move(to, their_direction, 1)
        promotions(to)
        |> list.map(move.new_pseudo(from:, to:, promotion: _))
      })

    let big_move =
      pawn_bb
      // mask only the pawns in our starting rank
      |> int.bitwise_and(bitboard.pawn_start_rank(us))
      |> bitboard.move(us_direction, 1)
      |> int.bitwise_and(int.bitwise_not(all_bitboard))
      |> bitboard.move(us_direction, 1)
      |> int.bitwise_and(int.bitwise_not(all_bitboard))
      |> bitboard.to_squares
      |> list.flat_map(fn(to) {
        let assert Ok(from) = square.move(to, their_direction, 2)
        promotions(to)
        |> list.map(move.new_pseudo(from:, to:, promotion: _))
      })

    let capture_move = {
      list.flat_map([direction.Left, direction.Right], fn(side) {
        pawn_bb
        |> bitboard.move(us_direction, 1)
        |> bitboard.move(side, 1)
        // for captures, we only don't include our own pieces
        |> int.bitwise_and(int.bitwise_not(us_bitboard))
        |> bitboard.to_squares
        |> list.flat_map(fn(to) {
          let assert Ok(from) =
            square.move(to, direction.opposite(side), 1)
            |> result.try(square.move(_, their_direction, 1))

          promotions(to)
          |> list.map(move.new_pseudo(from:, to:, promotion: _))
        })
      })
    }

    #(one_move, big_move, capture_move)
  }

  // We consider all moves that also count as captures (basically no pawns)
  let capturable_moves =
    us_pieces_list
    |> list.filter(fn(square_piece) { { square_piece.1 }.symbol != piece.Pawn })
    |> list.flat_map(fn(square_piece) {
      let #(from, piece) = square_piece

      // This is probably the most expensive section...
      // we just operate on squares, although we might be able to
      // switch this to bitboards at some point?
      // there's not much of a point though since we need it in square form
      // eventually
      square.piece_moves(from, piece)
      |> list.flat_map(fn(path) {
        // we check for collisions against pieces
        // if it's our own piece we stop
        // if it's opponent's piece we include it then stop
        list.fold_until(path, [], fn(acc, to) {
          case dict.get(game.board, to) {
            Ok(piece.Piece(player, _)) if player == us -> list.Stop(acc)
            Ok(piece.Piece(player, _)) if player != us -> list.Stop([to, ..acc])
            _ -> list.Continue([to, ..acc])
          }
        })
      })
      |> list.map(move.new_pseudo(from:, to: _, promotion: None))
    })

  let castle_moves =
    game.castling_availability
    |> list.filter(fn(castle_available) {
      let #(player, castle) = castle_available
      player == us
      && castle.occupancy_bitboard(player, castle)
      |> int.bitwise_and(all_bitboard)
      == 0
    })
    |> list.map(fn(castle_available) {
      let #(player, castle) = castle_available
      castle.king_move(player, castle)
    })

  list.flatten([
    pawn_moves_one,
    pawn_moves_two,
    pawn_moves_captures,
    capturable_moves,
    castle_moves,
  ])
}
