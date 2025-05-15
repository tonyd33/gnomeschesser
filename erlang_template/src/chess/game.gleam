import chess/bitboard
import chess/game/castle.{type Castle, KingSide, QueenSide}
import chess/move
import chess/move/disambiguation
import chess/piece
import chess/player
import chess/square
import gleam/bool
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import gleam/set
import gleam/string

pub const start_fen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

pub opaque type Game {
  Game(
    board: Dict(square.Square, piece.Piece),
    bitboard: bitboard.GameBitboard,
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
    |> result.map(pair.new(player.opponent(active_color), _))
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

  Game(
    board:,
    bitboard:,
    active_color:,
    castling_availability:,
    en_passant_target_square:,
    halfmove_clock:,
    fullmove_number:,
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

pub fn piece_exists_at(
  game: Game,
  piece: piece.Piece,
  square: square.Square,
) -> Bool {
  let bit =
    int.bitwise_shift_left(1, square.rank(square) * 8 + square.file(square))
  case piece {
    piece.Piece(player.White, piece.Pawn) ->
      int.bitwise_or(game.bitboard.white_pawns, bit)
    piece.Piece(player.White, piece.Knight) ->
      int.bitwise_or(game.bitboard.white_knights, bit)
    piece.Piece(player.White, piece.Bishop) ->
      int.bitwise_or(game.bitboard.white_bishops, bit)
    piece.Piece(player.White, piece.Rook) ->
      int.bitwise_or(game.bitboard.white_rooks, bit)
    piece.Piece(player.White, piece.Queen) ->
      int.bitwise_or(game.bitboard.white_queens, bit)
    piece.Piece(player.White, piece.King) ->
      int.bitwise_or(game.bitboard.white_king, bit)

    piece.Piece(player.Black, piece.Pawn) ->
      int.bitwise_or(game.bitboard.black_pawns, bit)
    piece.Piece(player.Black, piece.Knight) ->
      int.bitwise_or(game.bitboard.black_knights, bit)
    piece.Piece(player.Black, piece.Bishop) ->
      int.bitwise_or(game.bitboard.black_bishops, bit)
    piece.Piece(player.Black, piece.Rook) ->
      int.bitwise_or(game.bitboard.black_rooks, bit)
    piece.Piece(player.Black, piece.Queen) ->
      int.bitwise_or(game.bitboard.black_queens, bit)
    piece.Piece(player.Black, piece.King) ->
      int.bitwise_or(game.bitboard.black_king, bit)
  }
  != 0
}

pub fn empty_at(game: Game, square: square.Square) -> Bool {
  let square = bitboard.from_square(square)
  0 == int.bitwise_and(square, bitboard.get_bitboard_all(game.bitboard))
}

pub fn find_piece(game: Game, piece: piece.Piece) -> List(square.Square) {
  dict.filter(game.board, fn(_, p) { p == piece })
  |> dict.keys()
}

pub fn is_check(game: Game, player: player.Player) -> Bool {
  let assert Ok(#(king_position, _king_piece)) =
    game.board
    |> dict.to_list
    |> list.find(fn(x) { x.1 == piece.Piece(player, piece.King) })
  square.is_attacked_at(game.board, king_position, player.opponent(player))
}

pub fn is_checkmate(game: Game) -> Bool {
  let us = turn(game)
  is_check(game, us)
  && {
    valid_moves(game)
    |> list.all(fn(move) {
      // If every new move we try still result in a check, then it's checkmate
      apply(game, move) |> is_check(us)
    })
  }
}

pub fn is_stalemate(game: Game) -> Bool {
  !is_check(game, game.active_color) && valid_moves(game) |> list.is_empty
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

pub fn has_castled(game: Game, player: player.Player) {
  game.castling_availability
  |> list.find(fn(x) { x.0 == player })
  |> result.is_ok
}

pub fn can_castle(game: Game, player: player.Player) {
  !has_castled(game, player)
}

// There are functions that require the game state as well as move, those will go here
/// Standard Algebraic Notation
/// https://en.wikipedia.org/wiki/Algebraic_notation_(chess)
///
pub type SAN =
  String

/// Convert a move to SAN.
/// *This is expensive, so use it sparingly.*
/// TODO: make this not a result? not sure why it is
/// we can probably assume it's a valid move right
pub fn move_to_san(
  move: move.Move(move.ValidInContext),
  game: Game,
) -> Result(SAN, Nil) {
  let us = game.active_color
  let them = player.opponent(us)
  let from = move.get_from(move)
  let to = move.get_to(move)
  let assert Ok(us_piece) = dict.get(game.board, from)
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
        // find other valid_moves that have the same player and piece type that's targeting
        // don't include ourselves
        valid_moves(game)
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
              use <- bool.guard(
                move.get_to(other_move) != to
                  || move.equal(move, other_move)
                  || piece_at(game, other_from) != Ok(us_piece),
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
) -> Result(move.Move(move.ValidInContext), Nil) {
  valid_moves(game)
  |> list.find(fn(x) { move_to_san(x, game) == Ok(san) })
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
    castling_availability:,
    active_color: us,
    en_passant_target_square: _,
    fullmove_number:,
    halfmove_clock:,
  ) = game
  let them = player.opponent(us)
  let assert Ok(piece) = dict.get(board, from)
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

  let #(board, bitboard) = {
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

    #(board, bitboard)
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
          use <- bool.guard(piece == piece.Piece(player, piece.King), False)
          // Otherwise, continue the check
          True
        },
        False,
      )
      // check if the rooks are in the initial position
      let rook_in_starting_square =
        castle.rook_start_position(player, castle) |> dict.get(board, _)
        == Ok(piece.Piece(player, piece.Rook))
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
  let game =
    Game(
      board:,
      bitboard:,
      active_color: them,
      castling_availability:,
      en_passant_target_square:,
      fullmove_number:,
      halfmove_clock:,
    )

  game
}

pub fn find_player_king(
  game: Game,
  player: player.Player,
) -> Result(#(square.Square, piece.Piece), Nil) {
  pieces(game)
  |> list.find(fn(x) {
    let #(_, piece) = x
    piece.symbol == piece.King && piece.player == player
  })
}

// TODO: bring back explicitly validating it
pub fn validate_move(
  move: move.Move(move.Pseudo),
  game: Game,
) -> Result(move.Move(move.ValidInContext), Nil) {
  valid_moves(game) |> list.find(move.equal(_, move))
}

/// generate valid moves
pub fn valid_moves(game: Game) -> List(move.Move(move.ValidInContext)) {
  let us = game.active_color
  let them = player.opponent(us)

  let pieces = game.board |> dict.to_list

  // TODO: find the king faster!
  let king_piece = piece.Piece(us, piece.King)
  let assert [king_position] = find_piece(game, king_piece)

  // find attacks and pins to the king
  let #(king_attackers, king_blockers) = {
    let #(attackers, pins) =
      square.attacks_and_pins_to(game.board, king_position, them)
      |> list.partition(fn(x) { x.1 |> option.is_none })
    let attackers = list.map(attackers, pair.first)
    let blockers =
      list.map(pins, fn(x) {
        let assert #(attacker, Some(pinned)) = x
        #(pinned, attacker)
      })
      |> dict.from_list
    #(attackers, blockers)
  }

  // We always generate king moves to squares not attacked
  let king_moves = {
    let board_without_king =
      game.board
      |> dict.delete(king_position)
    square.piece_attack_offsets(king_piece)
    |> list.filter_map(fn(offset) {
      use to <- result.try(square.add(king_position, offset))
      let hit_piece = dict.get(game.board, to)
      // return early if we hit our own piece
      use <- bool.guard(
        hit_piece
          |> result.map(fn(x) { x.player == us })
          |> result.unwrap(False),
        Error(Nil),
      )
      // check if new square is attacked
      use <- bool.guard(
        square.is_attacked_at(board_without_king, to, them),
        Error(Nil),
      )

      let move_context =
        move.Context(
          capture: result.map(hit_piece, pair.new(to, _))
            |> option.from_result,
          piece: king_piece,
          castling: None,
        )
        |> Some
      move.new_valid(king_position, to, None, move_context) |> Ok
    })
  }

  // We can just pretend en passant doesn't exist, and calculate it specially

  // if there are 2 attackers or more, must always escape
  // so we can return just the king moves early
  use <- bool.guard(list.length(king_attackers) >= 2, king_moves)
  // past this point, there's either 0 or 1 king attacker

  // moves of regular pieces
  let regular_moves = {
    // if the king is attacked by a knight or a pawn, we only need to generate
    // moves that capture the attacker
    let only_capture_attacker_move = case
      result.try(list.first(king_attackers), dict.get(game.board, _))
    {
      Ok(x) if x.symbol == piece.Knight || x.symbol == piece.Pawn -> {
        let assert [attacker_square] = king_attackers
        let assert Ok(attacker_piece) = dict.get(game.board, attacker_square)
        square.get_squares_attacking_at(game.board, attacker_square, us)
        |> list.filter_map(fn(defender_square) {
          let assert Ok(piece) = dict.get(game.board, defender_square)
          use <- bool.guard(piece.symbol == piece.King, Error(Nil))
          let can_capture = case dict.get(king_blockers, defender_square) {
            Ok(pinner_square) -> {
              // If we're also a blocker, we need to make sure we're moving along the line of our pin
              // We calculate the offset between the new piece position and the original pinner
              // And compare it to the offset of the original position and the pinner
              // If the offset is the same (excluding sign), then it's along the same line
              let #(from_offset, _) =
                square.ray_to_offset(from: pinner_square, to: defender_square)
              let #(to_offset, _) =
                square.ray_to_offset(from: pinner_square, to: attacker_square)
              int.absolute_value(from_offset) == int.absolute_value(to_offset)
            }
            // We're not a blocker, so we're allowed to just capture the piece
            Error(_) -> True
          }
          use <- bool.guard(!can_capture, Error(Nil))

          let context =
            move.Context(
              capture: Some(#(attacker_square, attacker_piece)),
              piece:,
              castling: None,
            )
            |> Some
          move.new_valid(
            from: defender_square,
            to: attacker_square,
            promotion: None,
            context:,
          )
          |> Ok
        })
        |> Ok
      }
      _ -> Error(Nil)
    }
    use <- result.lazy_unwrap(only_capture_attacker_move)

    // These predicates exist to handle the cases where there is a check
    // They are separate because pawn moves are capture/non-capture
    // This predicates returns true if the target square is a valid capture
    let #(attackable_square_predicate, movable_square_predicate) = {
      case king_attackers {
        [king_attacker] -> {
          // if there is an attacker, the only valid moves is ones blocking the attack
          let blockable_spaces = {
            let #(attacker_offset, steps) =
              square.ray_to_offset(from: king_attacker, to: king_position)
            // if there's no space in between just return
            use <- bool.guard(steps <= 1, set.new())
            // we don't include the starting or ending square
            list.range(1, steps - 1)
            |> list.map(fn(depth) {
              let assert Ok(square) =
                square.add(king_attacker, depth * attacker_offset)
              square
            })
            |> set.from_list
          }
          // if there is an attacker, the only valid capture is the piece attacking the king
          // or a piece in between
          #(
            // for pieces that can capture, any move either capturing or blocking will do
            fn(square) { square == king_attacker },
            // for non-capturing moves, you need to physically block the path
            set.contains(blockable_spaces, _),
          )
        }
        [] -> #(
          // otherwise, just check if the piece is theirs
          fn(square) {
            case dict.get(game.board, square) {
              Ok(piece.Piece(player, _)) if player == them -> True
              _ -> False
            }
          },
          // check if square is empty
          fn(square) { dict.get(game.board, square) |> result.is_error },
        )
        _ -> panic
      }
    }
    pieces
    |> list.flat_map(fn(x) {
      let #(from, piece) = x
      use <- bool.guard(piece.player != us, [])
      // if this piece is pinned, we need to especially consider it
      let to_squares = case piece.symbol {
        piece.Knight | piece.Bishop | piece.Queen | piece.Rook ->
          square.piece_attacking(game.board, from, piece, True)
          |> list.filter(fn(x) {
            attackable_square_predicate(x) || movable_square_predicate(x)
          })

        piece.Pawn -> {
          let pawn_direction = piece.pawn_direction(us)
          let small_move =
            square.move(from, pawn_direction, 1)
            |> result.try(fn(x) {
              case movable_square_predicate(x) {
                True -> Ok(x)
                False -> Error(Nil)
              }
            })
          let big_move = {
            use <- bool.guard(
              square.rank(from) != square.pawn_start_rank(us),
              Error(Nil),
            )
            square.move(from, pawn_direction, 1)
            |> result.try(fn(square) {
              case dict.get(game.board, square) {
                Ok(_) -> Error(Nil)
                Error(Nil) -> Ok(square)
              }
            })
            |> result.try(square.move(_, pawn_direction, 1))
            |> result.try(fn(x) {
              case movable_square_predicate(x) {
                True -> Ok(x)
                False -> Error(Nil)
              }
            })
          }
          let x_move =
            square.piece_attacking(game.board, from, piece, True)
            |> list.filter(attackable_square_predicate)
          list.append([small_move, big_move] |> result.values, x_move)
        }
        // We already do king move generation separately
        piece.King -> []
      }

      // if we are pinned down, check if the target square is along the line
      dict.get(king_blockers, from)
      |> result.map(fn(pinner) {
        let from_offset: Int = square.ray_to_offset(from: pinner, to: from).0
        to_squares
        |> list.filter(fn(to) {
          to == pinner
          // if the to square is still along the same direction
          || from_offset == square.ray_to_offset(from: pinner, to: to).0
        })
      })
      |> result.unwrap(to_squares)
      |> list.flat_map(fn(to) {
        let capture =
          dict.get(game.board, to)
          |> result.map(pair.new(to, _))
          |> option.from_result
        let context =
          move.Context(capture:, piece:, castling: None)
          |> Some

        let promotions = {
          case square.rank(to) == square.pawn_promotion_rank(us), piece.symbol {
            True, piece.Pawn -> [
              Some(piece.Rook),
              Some(piece.Knight),
              Some(piece.Bishop),
              Some(piece.Queen),
            ]
            _, _ -> [None]
          }
        }
        promotions
        |> list.map(move.new_valid(from:, to:, promotion: _, context:))
      })
    })
  }

  // also check en passant explicitly, and see if it puts us in check
  // en passant is rare enough that we can get away with this explicit checking here
  let en_passant_move =
    game.en_passant_target_square
    |> option.then(fn(en_passant_square) {
      let #(player, to) = en_passant_square
      use <- bool.guard(player != them, None)
      let assert Ok(actual_big_pawn_square) =
        square.move(to, piece.pawn_direction(them), 1)

      let us_pawn = piece.Piece(us, piece.Pawn)
      let them_pawn = piece.Piece(them, piece.Pawn)

      square.piece_attack_offsets(them_pawn)
      |> list.filter_map(fn(offset) {
        use from <- result.try(square.add(to, offset))
        use piece <- result.try(dict.get(game.board, from))
        use <- bool.guard(piece != piece.Piece(us, piece.Pawn), Error(Nil))
        let new_board =
          dict.delete(game.board, from)
          |> dict.delete(actual_big_pawn_square)
          |> dict.insert(to, us_pawn)
        use <- bool.guard(
          square.is_attacked_at(new_board, king_position, them),
          Error(Nil),
        )
        let context =
          move.Context(
            capture: Some(#(actual_big_pawn_square, them_pawn)),
            piece: us_pawn,
            castling: None,
          )
          |> Some
        move.new_valid(from:, to:, promotion: None, context:) |> Ok
      })
      |> Some
    })
    |> option.unwrap([])

  // castling generation
  let castling_moves = {
    // if there's already an attacker, just don't try castling
    use <- bool.guard(!list.is_empty(king_attackers), [])
    game.castling_availability
    |> list.filter_map(fn(x) {
      let #(castle_player, castle) = x
      use <- bool.guard(castle_player != us, Error(Nil))
      let occupancy_blocked =
        castle.occupancy_squares(us, castle)
        |> list.any(fn(square) { dict.get(game.board, square) |> result.is_ok })
      use <- bool.guard(occupancy_blocked, Error(Nil))
      let attacked_somewhere =
        castle.unattacked_squares(us, castle)
        |> list.any(square.is_attacked_at(game.board, _, them))
      use <- bool.guard(attacked_somewhere, Error(Nil))

      let rank = square.player_rank(us)
      let to_file = case castle {
        castle.KingSide -> 6
        castle.QueenSide -> 2
      }
      let assert Ok(from) = square.from_rank_file(rank, square.king_file)
      let assert Ok(to) = square.from_rank_file(rank, to_file)
      let context =
        move.Context(
          capture: None,
          piece: piece.Piece(us, piece.King),
          castling: Some(castle),
        )
        |> Some
      move.new_valid(from:, to:, promotion: None, context:) |> Ok
    })
  }

  list.flatten([king_moves, regular_moves, en_passant_move, castling_moves])
}
