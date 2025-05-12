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
    // Also keep track of each individual piece's attacking bitboard
    // from each spot
    // This can be used to incrementally update the attacking bitboard too
    attacking_from: Dict(square.Square, bitboard.BitBoard),
    active_color: player.Player,
    castling_availability: List(#(player.Player, Castle)),
    en_passant_target_square: Option(#(player.Player, square.Square)),
    halfmove_clock: Int,
    fullmove_number: Int,
    // extra info
    // in check
    // pseudo moves generated?
    pseudo_moves: List(move.Move(move.Pseudo)),
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

  let attacking_from =
    board
    |> dict.map_values(fn(square, piece) {
      square.piece_attacking(board, square, piece, False)
      |> list.fold(0, fn(bitboard, square) {
        bitboard.from_square(square) |> int.bitwise_or(bitboard)
      })
    })

  let attacking = {
    use game_bitboard, square, piece_attacking <- dict.fold(
      attacking_from,
      bitboard.GameBitboard(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    )
    let assert Ok(piece) = dict.get(board, square)
    bitboard.or(game_bitboard, piece, piece_attacking)
  }
  let pseudo_moves =
    generate_pseudo_moves(board, bitboard, castling_availability, active_color)

  Game(
    board:,
    bitboard:,
    attacking:,
    attacking_from:,
    active_color:,
    castling_availability:,
    en_passant_target_square:,
    halfmove_clock:,
    fullmove_number:,
    pseudo_moves:,
  )
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
  checking_squares: bitboard.BitBoard,
  by by: player.Player,
) -> Bool {
  int.bitwise_and(
    bitboard.get_bitboard_player(game.attacking, by),
    checking_squares,
  )
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

pub fn is_check(game: Game, player: player.Player) -> Bool {
  bitboard.get_bitboard_piece(game.bitboard, piece.Piece(player, piece.King))
  |> is_attacked(game, _, player.opponent(player))
}

pub fn is_checkmate(game: Game) -> Bool {
  let us = turn(game)
  is_check(game, us)
  && {
    pseudo_moves(game)
    |> list.all(fn(move) {
      // If every new move we try still result in a check, then it's checkmate

      case
        validate_move(move, game)
        |> result.map(apply(game, _))
      {
        Ok(game) -> is_check(game, us)
        Error(Nil) -> True
      }
    })
  }
}

pub fn is_stalemate(game: Game) -> Bool {
  { !is_check(game, game.active_color) }
  && {
    !list.any(pseudo_moves(game), fn(move) {
      validate_move(move, game) |> result.is_ok
    })
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
  use move <- result.try(validate_move(move, game))
  let new_game = apply(game, move)

  // We can assume `move` is legal from this point on

  // Calculate castle moves
  let castle_san = case us_piece {
    piece.Piece(side, piece.King) -> {
      use <- bool.guard(
        move.equal(move, move.king_castle(side, KingSide)),
        Ok("O-O"),
      )
      use <- bool.guard(
        move.equal(move, move.king_castle(side, QueenSide)),
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
                  || result.is_error(validate_move(other_move, game)),
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

/// Validates the move to check if it's valid given the game state
pub fn validate_move(
  move: move.Move(a),
  game: Game,
) -> Result(move.Move(move.ValidInContext), Nil) {
  let from = move.get_from(move)
  let to = move.get_to(move)
  let promotion = move.get_promotion(move)
  let Game(
    board:,
    bitboard:,
    attacking:,
    attacking_from:,
    castling_availability: _,
    active_color: us,
    en_passant_target_square: _,
    fullmove_number: _,
    halfmove_clock: _,
    pseudo_moves: _,
  ) = game
  // we could assert the move is in pseudo_moves

  let them = player.opponent(us)
  use piece <- result.try(dict.get(board, from))

  // Return early if trying to move non-active player
  use <- bool.guard(piece.player != us, Error(Nil))

  // Get capture square and piece being captured (if exists)
  // Mostly relevant because pawns have some moves that are capture-only
  // Also handles going backwards for en-passant
  let capture =
    {
      use captured_square <- result.try(move_capture_square(move, game))
      use captured_piece <- result.try(dict.get(board, captured_square))
      use <- bool.guard(captured_piece.player != them, Error(Nil))
      Ok(#(captured_square, captured_piece))
    }
    |> option.from_result

  // If it's a pawn move that's trying to capture
  // there needs to be a piece actually there or it can't move
  // (unlike all other pieces)
  use <- bool.guard(
    piece.symbol == piece.Pawn
      && square.file(from) != square.file(to)
      && option.is_none(capture),
    Error(Nil),
  )

  let castling: Option(castle.Castle) = {
    use <- bool.guard(piece.symbol != piece.King, None)
    let from_file = square.file(from)
    let to_file = square.file(to)
    case from_file - to_file {
      // not a castle attempt
      -1 | 0 | 1 -> None
      x if x > 0 -> Some(castle.QueenSide)
      x if x < 0 -> Some(castle.KingSide)
      _ -> panic
    }
  }

  // Check if this move puts our king newly in check
  // This can only happen if a piece moves and allows a sliding
  // piece to attack the king
  // We already check if it is a king move itself putting us into check
  // We perform this by looking at the moved/captured piece
  // Then shooting a ray from the king
  use <- bool.guard(
    {
      // This block returns True if it's not a valid move
      // i.e. if the king ends up in check

      // If it's a castling move
      use <- option.lazy_unwrap(
        castling
        |> option.map(fn(castle_type) {
          // We can check for attacks onto the squares *before* the castle move, because
          // There's no situation where the attacker on these squares change
          // Based on the King/Rook position in a castle 
          castle.unattacked_bitboard(us, castle_type)
          |> is_attacked(game, _, by: them)
        }),
      )

      // if we are performing a king move
      // Check if we're moving into a safe or unsafe spot
      // We can use the current attacking bitboard
      // Because of how king moves work
      use <- bool.lazy_guard(piece.symbol == piece.King, fn() {
        bitboard.get_bitboard_player(attacking, them)
        |> int.bitwise_and(bitboard.from_square(to))
        != 0
      })

      let king_bitboard =
        bitboard.get_bitboard_piece(bitboard, piece.Piece(us, piece.King))
      let attackers =
        attacking_from
        |> dict.to_list
        |> list.filter_map(fn(x) {
          let #(square, attacking_bitboard) = x
          case attacking_bitboard |> int.bitwise_and(king_bitboard) {
            0 -> Error(Nil)
            _ ->
              dict.get(board, square)
              |> result.try(fn(piece) {
                case piece {
                  piece.Piece(player, _) if player == them ->
                    #(square, piece) |> Ok
                  _ -> Error(Nil)
                }
              })
          }
        })

      // If our king is currently in check, either a non-sliding check or more than 1, then this move is invalid at this point
      // The only way to escape that kind of check is moving the king (which we checked earlier)
      use <- bool.guard(
        case attackers {
          [#(_, piece.Piece(_, piece.King))] -> panic
          [_, _, ..]
          | [#(_, piece.Piece(_, piece.Knight))]
          | [#(_, piece.Piece(_, piece.Pawn))] -> True
          _ -> False
        },
        True,
      )

      // TODO: get this in a better way
      let king_square = {
        let assert [king_square] = bitboard.to_squares(king_bitboard)
        king_square
      }
      // at this point only things to worry about at this point is sliding checks (our moves can't trigger knight checks for example)
      // Either a sliding check is still there
      // Or we revealed on with our moves
      // Or we blocked an existing sliding check
      // Or nothing happened and there's no sliding checks
      // Either way, we shoot a ray along the "changed" squares
      // As well as squares that are still attacking the king
      let removed_squares =
        option.then(capture, fn(square_piece) {
          // if the capture square and to isn't the same, then we also need to remove the captured
          // this happens for en passant
          case square_piece.0 != to {
            True -> Some([from, square_piece.0])
            _ -> None
          }
        })
        |> option.unwrap([from])
      let attacker_squares =
        attacking_from
        |> dict.filter(fn(square, attacking_bitboard) {
          let assert Ok(piece) = dict.get(board, square)
          use <- bool.guard(piece.player == us, False)
          int.bitwise_and(attacking_bitboard, king_bitboard) != 0
        })
        |> dict.keys
      // Update the board for occupancy checking
      let updated_board =
        dict.drop(board, removed_squares) |> dict.insert(to, piece)

      // we can probably remove "to"
      [to, ..list.append(removed_squares, attacker_squares)]
      |> list.any(fn(x) {
        // shoot the ray here
        case square.piece_attacking_ray(updated_board, king_square, x) {
          Ok(piece) -> {
            // If we hit our own piece first, just return false
            use <- bool.guard(piece.player == us, False)
            let is_diagonal = {
              // we check if both bytes are different from each other
              let difference =
                int.bitwise_exclusive_or(
                  square.to_ox88(king_square),
                  square.to_ox88(x),
                )

              int.bitwise_and(0xF0, difference) != 0
              && int.bitwise_and(0x0F, difference) != 0
            }
            case piece.symbol, is_diagonal {
              piece.Bishop, True -> True
              piece.Rook, False -> True
              piece.Queen, _ -> True
              _, _ -> False
            }
          }
          Error(Nil) -> False
        }
      })
    },
    Error(Nil),
  )

  let context =
    move.Context(capture:, piece:, castling:)
    |> Some

  move.new_valid(from:, to:, promotion:, context:)
  |> Ok
}

/// Applies a move to a game, takes either pseudo or validated moves
/// Returns a validated version of the move
/// TODO: we could return the new validated move?
pub fn apply(game: Game, move: move.Move(move.ValidInContext)) -> Game {
  let from = move.get_from(move)
  let to = move.get_to(move)
  let promotion = move.get_promotion(move)
  let move_context = move.get_context(move)
  let Game(
    board:,
    bitboard:,
    // We completely regenerate attacking and attacking_from
    attacking: _,
    attacking_from: _,
    castling_availability:,
    active_color: us,
    en_passant_target_square: _,
    fullmove_number:,
    halfmove_clock:,
    pseudo_moves:,
  ) = game
  let them = player.opponent(us)

  // en passant target square update
  // if it's a pawn move and it has a 2 rank difference
  let en_passant_target_square = case move_context.piece.symbol {
    piece.Pawn ->
      case square.rank(from) - square.rank(to) {
        2 | -2 -> {
          let assert Ok(square) = square.move(from, player.direction(us), 1)
          #(us, square) |> Some
        }
        _ -> None
      }
    _ -> None
  }

  let #(board, bitboard, attacking, attacking_from) = {
    // update the piece if it's a promotion
    let new_piece =
      promotion
      |> option.map(piece.Piece(us, _))
      |> option.unwrap(move_context.piece)
    // Retrieve the move a rook would have if castling
    let castle_rook_move =
      move_context.castling
      |> option.map(move.rook_castle(us, _))
    // Collect deletion and insertion of data
    let deletion =
      [
        Some(#(from, move_context.piece)),
        move_context.capture,
        castle_rook_move
          |> option.map(fn(x) {
            #(move.get_from(x), piece.Piece(us, piece.Rook))
          }),
      ]
      |> option.values
    let insertion =
      [
        Some(#(to, new_piece)),
        castle_rook_move
          |> option.map(fn(x) { #(move.get_to(x), piece.Piece(us, piece.Rook)) }),
      ]
      |> option.values

    // TODO: optimize this, better dict operations?
    let board =
      list.fold(deletion, board, fn(board, square_piece) {
        dict.delete(board, square_piece.0)
      })
      |> dict.merge(dict.from_list(insertion))
    let bitboard =
      bitboard
      |> list.fold(deletion, _, fn(bitboard, square_piece) {
        let #(square, piece) = square_piece
        // mask it out
        bitboard.and(
          bitboard,
          piece,
          int.bitwise_not(bitboard.from_square(square)),
        )
      })
      |> list.fold(insertion, _, fn(bitboard, square_piece) {
        let #(square, piece) = square_piece
        // mask it in
        bitboard.or(bitboard, piece, bitboard.from_square(square))
      })

    let attacking_from =
      board
      |> dict.map_values(fn(square, piece) {
        square.piece_attacking(board, square, piece, False)
        |> list.fold(0, fn(bitboard, square) {
          bitboard.from_square(square) |> int.bitwise_or(bitboard)
        })
      })

    // Ideally we can incrementally update this dict, but it doesn't seem possible right now
    //  // Remove from attacking bitboard while we still have the old attacking_from
    //     let attacking_from =
    //       attacking_from
    //       |> echo
    //       |> list.fold(deletion, _, fn(attacking_from, square_piece) {
    //         let #(square, _piece) = square_piece
    //         // remove this attacking info from this square
    //         dict.delete(attacking_from, square)
    //       })
    //       |> list.fold(insertion, _, fn(attacking_from, square_piece) {
    //         let #(square, piece) = square_piece
    //         let attacking_bitboard =
    //           square.piece_attacking(board, square, piece)
    //           |> list.fold(0, fn(acc, x) {
    //             bitboard.from_square(x)
    //             |> int.bitwise_or(acc)
    //           })
    //         dict.insert(attacking_from, square, attacking_bitboard)
    //       })

    // completely update the attacking bitboard now that we have the new attacking_from
    let attacking = {
      // This actually calls to_list, we'll see if that's fine
      // it should call native code through erlang
      use game_bitboard, square, piece_attacking <- dict.fold(
        attacking_from,
        bitboard.GameBitboard(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
      )
      let assert Ok(piece) = dict.get(board, square)
      bitboard.or(game_bitboard, piece, piece_attacking)
    }

    // TODO: patch attacking bitboard incrementally
    #(board, bitboard, attacking, attacking_from)
  }

  // update castling availibility based on new game state
  let castling_availability =
    castling_availability
    |> list.filter(fn(x) {
      let #(player, castle) = x
      use <- bool.guard(
        !{
          // This expression returns false to short-circuit 
          // If it's not us, continue the checks
          use <- bool.guard(player != us, True)
          // If we castled, remove this availability
          use <- bool.guard(move_context.castling |> option.is_some, False)
          // Otherwise, check if our king has moved
          let king_piece = piece.Piece(us, piece.King)
          use <- bool.guard(
            castle.king_initial_bitboard(us)
              != bitboard.get_bitboard_piece(bitboard, king_piece),
            False,
          )
          // Otherwise, continue the check
          True
        },
        False,
      )
      // check if the rooks are in the initial position
      let rook_in_starting_square =
        int.bitwise_and(
          castle.rook_initial_bitboard(player, castle),
          bitboard.get_bitboard_piece(bitboard, piece.Piece(player, piece.Rook)),
        )
        != 0
      rook_in_starting_square
    })

  let fullmove_number = case us {
    player.Black -> fullmove_number + 1
    player.White -> fullmove_number
  }
  let halfmove_clock = case move_context.piece.symbol, move_context.capture {
    piece.Pawn, _ | _, Some(_) -> 0
    _, _ -> halfmove_clock + 1
  }
  let pseudo_moves =
    generate_pseudo_moves(board, bitboard, castling_availability, them)
  let game =
    Game(
      board:,
      bitboard:,
      attacking:,
      attacking_from:,
      active_color: them,
      castling_availability:,
      en_passant_target_square:,
      fullmove_number:,
      halfmove_clock:,
      pseudo_moves:,
    )

  game
}

/// Generate moves that don't care about checks
/// It only ensures that moves are moving into unoccupied space (or a capture)
/// And also that castles aren't occupied by pieces
/// but it does not check if there's an attack in the way
pub fn pseudo_moves(game: Game) -> List(move.Move(move.Pseudo)) {
  game.pseudo_moves
}

fn generate_pseudo_moves(
  board: dict.Dict(square.Square, piece.Piece),
  bitboard: bitboard.GameBitboard,
  castling_availability: List(#(player.Player, Castle)),
  player: player.Player,
) -> List(move.Move(move.Pseudo)) {
  let us = player
  let all_bitboard = bitboard.get_bitboard_all(bitboard)
  let us_pieces_list =
    board
    |> dict.to_list
    |> list.filter(fn(square_piece) { { square_piece.1 }.player == us })

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
  let #(pawn_moves_one, pawn_moves_two) = {
    let pawn_bb =
      bitboard.get_bitboard_piece(bitboard, piece.Piece(us, piece.Pawn))

    // The direction that our pawns travel
    let us_direction = case us {
      player.White -> direction.Up
      player.Black -> direction.Down
    }
    let their_direction = direction.opposite(us_direction)

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
    #(one_move, big_move)
  }

  // We consider all moves that also count as captures
  // for pawns this also includes en passant
  let capturable_moves =
    us_pieces_list
    |> list.flat_map(fn(square_piece) {
      let #(from, piece) = square_piece
      square.piece_attacking(board, from, piece, True)
      |> list.flat_map(fn(to) {
        case piece.symbol == piece.Pawn {
          True -> promotions(to)
          False -> [None]
        }
        |> list.map(move.new_pseudo(from:, to:, promotion: _))
      })
    })

  let castle_moves =
    castling_availability
    |> list.filter(fn(castle_available) {
      let #(player, castle) = castle_available
      player == us
      && castle.occupancy_bitboard(player, castle)
      |> int.bitwise_and(all_bitboard)
      == 0
    })
    |> list.map(fn(castle_available) {
      let #(player, castle) = castle_available
      move.king_castle(player, castle)
    })

  // list.flatten seems to be slow
  list.flatten([pawn_moves_one, pawn_moves_two, capturable_moves, castle_moves])
}
