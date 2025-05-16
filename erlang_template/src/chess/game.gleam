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
import util/direction
import util/yielder

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
    hash: Hash,
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
  let hash =
    compute_zobrist_hash_impl(
      active_color,
      board,
      bitboard,
      castling_availability,
      en_passant_target_square,
    )

  Game(
    board:,
    bitboard:,
    active_color:,
    castling_availability:,
    en_passant_target_square:,
    halfmove_clock:,
    fullmove_number:,
    hash:,
  )
  |> Ok
}

pub fn turn(game: Game) -> player.Player {
  game.active_color
}

pub fn board(game: Game) -> Dict(square.Square, piece.Piece) {
  game.board
}

pub fn hash(game: Game) -> Hash {
  game.hash
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
// pub fn is_insufficient_material(_game: Game) -> Bool {
//   todo
// }

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

type GameOp {
  BoardInsertion(square: square.Square, piece: piece.Piece)
  BoardDeletion(square: square.Square, piece: piece.Piece)
}

fn map_bbh(bbh, op) {
  case op {
    BoardDeletion(square, piece) -> {
      let #(board, bitboard, hash) = bbh
      #(
        dict.delete(board, square),
        // mask it out
        bitboard.and(
          bitboard,
          piece,
          int.bitwise_not(bitboard.from_square(square)),
        ),
        // (un)XOR squares out
        int.bitwise_exclusive_or(hash, piece_hash(square, piece)),
      )
    }
    BoardInsertion(square, piece) -> {
      let #(board, bitboard, hash) = bbh
      #(
        dict.insert(board, square, piece),
        // mask it in
        bitboard.or(bitboard, piece, bitboard.from_square(square)),
        // XOR squares in
        int.bitwise_exclusive_or(hash, piece_hash(square, piece)),
      )
    }
  }
}

/// Applies a move to a game, takes either pseudo or validated moves
/// Returns a validated version of the move
/// TODO: we could return the new validated move?
///
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
    en_passant_target_square:,
    fullmove_number:,
    halfmove_clock:,
    hash:,
  ) = game
  // TODO: We can be very slightly more efficient by perhaps caching this or
  // accounting for the previous hash smartly. See [Disservin's C++ chess library](https://github.com/Disservin/chess-library/blob/1f60cef1b708a78c02bff473f5de6ef544436560/include/chess.hpp#L2023)
  let prev_castle_hash = castle_hash(castling_availability)
  let prev_ep_hash = ep_hash(us, bitboard, en_passant_target_square)
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

  // Updates to the board.
  let #(board, bitboard, hash) = {
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

    // Over the course of hundreds of thousands of nodes, manually doing this
    // rather than folding over a list is marginally but measurably faster.
    let bbh = #(board, bitboard, hash)
    let bbh = map_bbh(bbh, BoardDeletion(from, move_context.piece))
    let bbh = case move_context.capture {
      Some(x) -> map_bbh(bbh, BoardDeletion(x.0, x.1))
      None -> bbh
    }
    let bbh = case castle_rook_move {
      Some(x) ->
        map_bbh(
          bbh,
          BoardDeletion(move.get_from(x), piece.Piece(us, piece.Rook)),
        )
      None -> bbh
    }
    let bbh = map_bbh(bbh, BoardInsertion(to, new_piece))
    let bbh = case castle_rook_move {
      Some(x) ->
        map_bbh(
          bbh,
          BoardInsertion(move.get_to(x), piece.Piece(us, piece.Rook)),
        )
      None -> bbh
    }
    bbh
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

  let hash =
    hash
    // Turn
    |> int.bitwise_exclusive_or(hashes.780)
    // En passant hash
    |> int.bitwise_exclusive_or(prev_ep_hash)
    |> int.bitwise_exclusive_or(ep_hash(
      them,
      bitboard,
      en_passant_target_square,
    ))
    // Castle rights
    |> int.bitwise_exclusive_or(prev_castle_hash)
    |> int.bitwise_exclusive_or(castle_hash(castling_availability))

  let game =
    Game(
      board:,
      bitboard:,
      active_color: them,
      castling_availability:,
      en_passant_target_square:,
      fullmove_number:,
      halfmove_clock:,
      hash:,
    )

  game
}

pub fn find_player_king(game: Game, player: player.Player) -> square.Square {
  let assert [a] = find_piece(game, piece.Piece(player, piece.King))
  a
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
  let pieces_yielder = pieces |> yielder.from_list

  let king_piece = piece.Piece(us, piece.King)
  // let king_position = find_player_king(game, us)
  let assert [king_position] = find_piece(game, king_piece)

  // find attacks and pins to the king
  let #(king_attackers, king_blockers) = {
    let #(attackers, pins) =
      square.attacks_and_pins_to(
        pieces_yielder,
        game.board,
        king_position,
        them,
      )
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
        square.get_squares_attacking_at(
          game.board,
          pieces_yielder,
          attacker_square,
          us,
        )
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

// Zobrist below

// A zobrist implementation that matches http://hgm.nubati.net/book_format.html
// TODO: Implement cheap updates to zobrist based on move applied
// We can probably keep the zobrist stuff in this file by removing the dependency for game.gleam
// Or we just move all of this into game.gleam

const piece_offset = 0

const castle_offset = 768

const en_passant_offset = 772

const turn_offset = 780

pub type Hash =
  Int

/// Expensive! This re-computes the hash. Use `hash()` instead.
///
pub fn compute_zobrist_hash(game: Game) {
  compute_zobrist_hash_impl(
    game.active_color,
    game.board,
    game.bitboard,
    game.castling_availability,
    game.en_passant_target_square,
  )
}

/// Why is there `compute_zobrist_hash` and this function? The `hash` is part
/// of the `Game` and should be computed _before_ the `Game` is created.
/// Therefore, we run into a big of a chicken-and-egg problem when we need to
/// create a Game from scratch (e.g. loading FEN)
///
fn compute_zobrist_hash_impl(
  us: player.Player,
  board: Dict(square.Square, piece.Piece),
  bb: bitboard.GameBitboard,
  castling_availability: List(#(player.Player, Castle)),
  en_passant_target_square: Option(#(player.Player, square.Square)),
) -> Hash {
  let piece_hash =
    dict.to_list(board)
    |> list.fold(0x0, fn(acc, x) {
      int.bitwise_exclusive_or(acc, piece_hash(x.0, x.1))
    })

  let castle_hash = castle_hash(castling_availability)

  let en_passant_hash = ep_hash(us, bb, en_passant_target_square)

  let turn_hash = case us {
    player.White -> {
      let assert Ok(hash) = get_hash(turn_offset)
      hash
    }
    player.Black -> 0x0
  }

  piece_hash
  |> int.bitwise_exclusive_or(castle_hash)
  |> int.bitwise_exclusive_or(en_passant_hash)
  |> int.bitwise_exclusive_or(turn_hash)
}

fn castle_hash(castling_availability) {
  castling_availability
  |> list.fold(0x0, fn(acc, x) {
    let castle_type = case x {
      #(player.White, castle.KingSide) -> 0
      #(player.White, castle.QueenSide) -> 1
      #(player.Black, castle.KingSide) -> 2
      #(player.Black, castle.QueenSide) -> 3
    }
    let assert Ok(hash) = get_hash(castle_type + castle_offset)
    int.bitwise_exclusive_or(acc, hash)
  })
}

fn ep_hash(
  us: player.Player,
  bb: bitboard.GameBitboard,
  en_passant_target_square: Option(#(player.Player, square.Square)),
) {
  en_passant_target_square
  // The en passant hash is only factored in if there is a piece to capture
  // the en passant target square. We try to find it by checking the squares
  // to the diagonal left and diagonal right of the en passant target square.
  |> option.map(fn(square) {
    let #(_, square) = square

    let dir = case us {
      player.Black -> direction.Up
      player.White -> direction.Down
    }
    let x_left =
      square.move(square, direction.Left, 1)
      |> result.try(square.move(_, dir, 1))
      |> result.map(bitboard.from_square)
      |> result.unwrap(0x0)
    let x_right =
      square.move(square, direction.Right, 1)
      |> result.try(square.move(_, dir, 1))
      |> result.map(bitboard.from_square)
      |> result.unwrap(0x0)

    let can_attack =
      {
        int.bitwise_or(x_left, x_right)
        |> int.bitwise_and(case us {
          player.Black -> bb.black_pawns
          player.White -> bb.white_pawns
        })
      }
      != 0

    case can_attack {
      True -> {
        let assert Ok(hash) = get_hash(en_passant_offset + square.file(square))
        hash
      }
      False -> 0x0
    }
  })
  |> option.unwrap(0x0)
}

pub fn piece_hash(square: square.Square, piece: piece.Piece) -> Hash {
  let piece_type = case piece {
    piece.Piece(player.Black, piece.Pawn) -> 0
    piece.Piece(player.White, piece.Pawn) -> 1
    piece.Piece(player.Black, piece.Knight) -> 2
    piece.Piece(player.White, piece.Knight) -> 3
    piece.Piece(player.Black, piece.Bishop) -> 4
    piece.Piece(player.White, piece.Bishop) -> 5
    piece.Piece(player.Black, piece.Rook) -> 6
    piece.Piece(player.White, piece.Rook) -> 7
    piece.Piece(player.Black, piece.Queen) -> 8
    piece.Piece(player.White, piece.Queen) -> 9
    piece.Piece(player.Black, piece.King) -> 10
    piece.Piece(player.White, piece.King) -> 11
  }
  let assert Ok(hash) =
    get_hash(
      { 64 * piece_type }
      + { { square.rank(square) * 8 } + { square.file(square) } }
      + piece_offset,
    )
  hash
}

pub fn get_hash(index: Int) -> Result(Hash, Nil) {
  case index {
    0 -> Ok(hashes.0)
    1 -> Ok(hashes.1)
    2 -> Ok(hashes.2)
    3 -> Ok(hashes.3)
    4 -> Ok(hashes.4)
    5 -> Ok(hashes.5)
    6 -> Ok(hashes.6)
    7 -> Ok(hashes.7)
    8 -> Ok(hashes.8)
    9 -> Ok(hashes.9)
    10 -> Ok(hashes.10)
    11 -> Ok(hashes.11)
    12 -> Ok(hashes.12)
    13 -> Ok(hashes.13)
    14 -> Ok(hashes.14)
    15 -> Ok(hashes.15)
    16 -> Ok(hashes.16)
    17 -> Ok(hashes.17)
    18 -> Ok(hashes.18)
    19 -> Ok(hashes.19)
    20 -> Ok(hashes.20)
    21 -> Ok(hashes.21)
    22 -> Ok(hashes.22)
    23 -> Ok(hashes.23)
    24 -> Ok(hashes.24)
    25 -> Ok(hashes.25)
    26 -> Ok(hashes.26)
    27 -> Ok(hashes.27)
    28 -> Ok(hashes.28)
    29 -> Ok(hashes.29)
    30 -> Ok(hashes.30)
    31 -> Ok(hashes.31)
    32 -> Ok(hashes.32)
    33 -> Ok(hashes.33)
    34 -> Ok(hashes.34)
    35 -> Ok(hashes.35)
    36 -> Ok(hashes.36)
    37 -> Ok(hashes.37)
    38 -> Ok(hashes.38)
    39 -> Ok(hashes.39)
    40 -> Ok(hashes.40)
    41 -> Ok(hashes.41)
    42 -> Ok(hashes.42)
    43 -> Ok(hashes.43)
    44 -> Ok(hashes.44)
    45 -> Ok(hashes.45)
    46 -> Ok(hashes.46)
    47 -> Ok(hashes.47)
    48 -> Ok(hashes.48)
    49 -> Ok(hashes.49)
    50 -> Ok(hashes.50)
    51 -> Ok(hashes.51)
    52 -> Ok(hashes.52)
    53 -> Ok(hashes.53)
    54 -> Ok(hashes.54)
    55 -> Ok(hashes.55)
    56 -> Ok(hashes.56)
    57 -> Ok(hashes.57)
    58 -> Ok(hashes.58)
    59 -> Ok(hashes.59)
    60 -> Ok(hashes.60)
    61 -> Ok(hashes.61)
    62 -> Ok(hashes.62)
    63 -> Ok(hashes.63)
    64 -> Ok(hashes.64)
    65 -> Ok(hashes.65)
    66 -> Ok(hashes.66)
    67 -> Ok(hashes.67)
    68 -> Ok(hashes.68)
    69 -> Ok(hashes.69)
    70 -> Ok(hashes.70)
    71 -> Ok(hashes.71)
    72 -> Ok(hashes.72)
    73 -> Ok(hashes.73)
    74 -> Ok(hashes.74)
    75 -> Ok(hashes.75)
    76 -> Ok(hashes.76)
    77 -> Ok(hashes.77)
    78 -> Ok(hashes.78)
    79 -> Ok(hashes.79)
    80 -> Ok(hashes.80)
    81 -> Ok(hashes.81)
    82 -> Ok(hashes.82)
    83 -> Ok(hashes.83)
    84 -> Ok(hashes.84)
    85 -> Ok(hashes.85)
    86 -> Ok(hashes.86)
    87 -> Ok(hashes.87)
    88 -> Ok(hashes.88)
    89 -> Ok(hashes.89)
    90 -> Ok(hashes.90)
    91 -> Ok(hashes.91)
    92 -> Ok(hashes.92)
    93 -> Ok(hashes.93)
    94 -> Ok(hashes.94)
    95 -> Ok(hashes.95)
    96 -> Ok(hashes.96)
    97 -> Ok(hashes.97)
    98 -> Ok(hashes.98)
    99 -> Ok(hashes.99)
    100 -> Ok(hashes.100)
    101 -> Ok(hashes.101)
    102 -> Ok(hashes.102)
    103 -> Ok(hashes.103)
    104 -> Ok(hashes.104)
    105 -> Ok(hashes.105)
    106 -> Ok(hashes.106)
    107 -> Ok(hashes.107)
    108 -> Ok(hashes.108)
    109 -> Ok(hashes.109)
    110 -> Ok(hashes.110)
    111 -> Ok(hashes.111)
    112 -> Ok(hashes.112)
    113 -> Ok(hashes.113)
    114 -> Ok(hashes.114)
    115 -> Ok(hashes.115)
    116 -> Ok(hashes.116)
    117 -> Ok(hashes.117)
    118 -> Ok(hashes.118)
    119 -> Ok(hashes.119)
    120 -> Ok(hashes.120)
    121 -> Ok(hashes.121)
    122 -> Ok(hashes.122)
    123 -> Ok(hashes.123)
    124 -> Ok(hashes.124)
    125 -> Ok(hashes.125)
    126 -> Ok(hashes.126)
    127 -> Ok(hashes.127)
    128 -> Ok(hashes.128)
    129 -> Ok(hashes.129)
    130 -> Ok(hashes.130)
    131 -> Ok(hashes.131)
    132 -> Ok(hashes.132)
    133 -> Ok(hashes.133)
    134 -> Ok(hashes.134)
    135 -> Ok(hashes.135)
    136 -> Ok(hashes.136)
    137 -> Ok(hashes.137)
    138 -> Ok(hashes.138)
    139 -> Ok(hashes.139)
    140 -> Ok(hashes.140)
    141 -> Ok(hashes.141)
    142 -> Ok(hashes.142)
    143 -> Ok(hashes.143)
    144 -> Ok(hashes.144)
    145 -> Ok(hashes.145)
    146 -> Ok(hashes.146)
    147 -> Ok(hashes.147)
    148 -> Ok(hashes.148)
    149 -> Ok(hashes.149)
    150 -> Ok(hashes.150)
    151 -> Ok(hashes.151)
    152 -> Ok(hashes.152)
    153 -> Ok(hashes.153)
    154 -> Ok(hashes.154)
    155 -> Ok(hashes.155)
    156 -> Ok(hashes.156)
    157 -> Ok(hashes.157)
    158 -> Ok(hashes.158)
    159 -> Ok(hashes.159)
    160 -> Ok(hashes.160)
    161 -> Ok(hashes.161)
    162 -> Ok(hashes.162)
    163 -> Ok(hashes.163)
    164 -> Ok(hashes.164)
    165 -> Ok(hashes.165)
    166 -> Ok(hashes.166)
    167 -> Ok(hashes.167)
    168 -> Ok(hashes.168)
    169 -> Ok(hashes.169)
    170 -> Ok(hashes.170)
    171 -> Ok(hashes.171)
    172 -> Ok(hashes.172)
    173 -> Ok(hashes.173)
    174 -> Ok(hashes.174)
    175 -> Ok(hashes.175)
    176 -> Ok(hashes.176)
    177 -> Ok(hashes.177)
    178 -> Ok(hashes.178)
    179 -> Ok(hashes.179)
    180 -> Ok(hashes.180)
    181 -> Ok(hashes.181)
    182 -> Ok(hashes.182)
    183 -> Ok(hashes.183)
    184 -> Ok(hashes.184)
    185 -> Ok(hashes.185)
    186 -> Ok(hashes.186)
    187 -> Ok(hashes.187)
    188 -> Ok(hashes.188)
    189 -> Ok(hashes.189)
    190 -> Ok(hashes.190)
    191 -> Ok(hashes.191)
    192 -> Ok(hashes.192)
    193 -> Ok(hashes.193)
    194 -> Ok(hashes.194)
    195 -> Ok(hashes.195)
    196 -> Ok(hashes.196)
    197 -> Ok(hashes.197)
    198 -> Ok(hashes.198)
    199 -> Ok(hashes.199)
    200 -> Ok(hashes.200)
    201 -> Ok(hashes.201)
    202 -> Ok(hashes.202)
    203 -> Ok(hashes.203)
    204 -> Ok(hashes.204)
    205 -> Ok(hashes.205)
    206 -> Ok(hashes.206)
    207 -> Ok(hashes.207)
    208 -> Ok(hashes.208)
    209 -> Ok(hashes.209)
    210 -> Ok(hashes.210)
    211 -> Ok(hashes.211)
    212 -> Ok(hashes.212)
    213 -> Ok(hashes.213)
    214 -> Ok(hashes.214)
    215 -> Ok(hashes.215)
    216 -> Ok(hashes.216)
    217 -> Ok(hashes.217)
    218 -> Ok(hashes.218)
    219 -> Ok(hashes.219)
    220 -> Ok(hashes.220)
    221 -> Ok(hashes.221)
    222 -> Ok(hashes.222)
    223 -> Ok(hashes.223)
    224 -> Ok(hashes.224)
    225 -> Ok(hashes.225)
    226 -> Ok(hashes.226)
    227 -> Ok(hashes.227)
    228 -> Ok(hashes.228)
    229 -> Ok(hashes.229)
    230 -> Ok(hashes.230)
    231 -> Ok(hashes.231)
    232 -> Ok(hashes.232)
    233 -> Ok(hashes.233)
    234 -> Ok(hashes.234)
    235 -> Ok(hashes.235)
    236 -> Ok(hashes.236)
    237 -> Ok(hashes.237)
    238 -> Ok(hashes.238)
    239 -> Ok(hashes.239)
    240 -> Ok(hashes.240)
    241 -> Ok(hashes.241)
    242 -> Ok(hashes.242)
    243 -> Ok(hashes.243)
    244 -> Ok(hashes.244)
    245 -> Ok(hashes.245)
    246 -> Ok(hashes.246)
    247 -> Ok(hashes.247)
    248 -> Ok(hashes.248)
    249 -> Ok(hashes.249)
    250 -> Ok(hashes.250)
    251 -> Ok(hashes.251)
    252 -> Ok(hashes.252)
    253 -> Ok(hashes.253)
    254 -> Ok(hashes.254)
    255 -> Ok(hashes.255)
    256 -> Ok(hashes.256)
    257 -> Ok(hashes.257)
    258 -> Ok(hashes.258)
    259 -> Ok(hashes.259)
    260 -> Ok(hashes.260)
    261 -> Ok(hashes.261)
    262 -> Ok(hashes.262)
    263 -> Ok(hashes.263)
    264 -> Ok(hashes.264)
    265 -> Ok(hashes.265)
    266 -> Ok(hashes.266)
    267 -> Ok(hashes.267)
    268 -> Ok(hashes.268)
    269 -> Ok(hashes.269)
    270 -> Ok(hashes.270)
    271 -> Ok(hashes.271)
    272 -> Ok(hashes.272)
    273 -> Ok(hashes.273)
    274 -> Ok(hashes.274)
    275 -> Ok(hashes.275)
    276 -> Ok(hashes.276)
    277 -> Ok(hashes.277)
    278 -> Ok(hashes.278)
    279 -> Ok(hashes.279)
    280 -> Ok(hashes.280)
    281 -> Ok(hashes.281)
    282 -> Ok(hashes.282)
    283 -> Ok(hashes.283)
    284 -> Ok(hashes.284)
    285 -> Ok(hashes.285)
    286 -> Ok(hashes.286)
    287 -> Ok(hashes.287)
    288 -> Ok(hashes.288)
    289 -> Ok(hashes.289)
    290 -> Ok(hashes.290)
    291 -> Ok(hashes.291)
    292 -> Ok(hashes.292)
    293 -> Ok(hashes.293)
    294 -> Ok(hashes.294)
    295 -> Ok(hashes.295)
    296 -> Ok(hashes.296)
    297 -> Ok(hashes.297)
    298 -> Ok(hashes.298)
    299 -> Ok(hashes.299)
    300 -> Ok(hashes.300)
    301 -> Ok(hashes.301)
    302 -> Ok(hashes.302)
    303 -> Ok(hashes.303)
    304 -> Ok(hashes.304)
    305 -> Ok(hashes.305)
    306 -> Ok(hashes.306)
    307 -> Ok(hashes.307)
    308 -> Ok(hashes.308)
    309 -> Ok(hashes.309)
    310 -> Ok(hashes.310)
    311 -> Ok(hashes.311)
    312 -> Ok(hashes.312)
    313 -> Ok(hashes.313)
    314 -> Ok(hashes.314)
    315 -> Ok(hashes.315)
    316 -> Ok(hashes.316)
    317 -> Ok(hashes.317)
    318 -> Ok(hashes.318)
    319 -> Ok(hashes.319)
    320 -> Ok(hashes.320)
    321 -> Ok(hashes.321)
    322 -> Ok(hashes.322)
    323 -> Ok(hashes.323)
    324 -> Ok(hashes.324)
    325 -> Ok(hashes.325)
    326 -> Ok(hashes.326)
    327 -> Ok(hashes.327)
    328 -> Ok(hashes.328)
    329 -> Ok(hashes.329)
    330 -> Ok(hashes.330)
    331 -> Ok(hashes.331)
    332 -> Ok(hashes.332)
    333 -> Ok(hashes.333)
    334 -> Ok(hashes.334)
    335 -> Ok(hashes.335)
    336 -> Ok(hashes.336)
    337 -> Ok(hashes.337)
    338 -> Ok(hashes.338)
    339 -> Ok(hashes.339)
    340 -> Ok(hashes.340)
    341 -> Ok(hashes.341)
    342 -> Ok(hashes.342)
    343 -> Ok(hashes.343)
    344 -> Ok(hashes.344)
    345 -> Ok(hashes.345)
    346 -> Ok(hashes.346)
    347 -> Ok(hashes.347)
    348 -> Ok(hashes.348)
    349 -> Ok(hashes.349)
    350 -> Ok(hashes.350)
    351 -> Ok(hashes.351)
    352 -> Ok(hashes.352)
    353 -> Ok(hashes.353)
    354 -> Ok(hashes.354)
    355 -> Ok(hashes.355)
    356 -> Ok(hashes.356)
    357 -> Ok(hashes.357)
    358 -> Ok(hashes.358)
    359 -> Ok(hashes.359)
    360 -> Ok(hashes.360)
    361 -> Ok(hashes.361)
    362 -> Ok(hashes.362)
    363 -> Ok(hashes.363)
    364 -> Ok(hashes.364)
    365 -> Ok(hashes.365)
    366 -> Ok(hashes.366)
    367 -> Ok(hashes.367)
    368 -> Ok(hashes.368)
    369 -> Ok(hashes.369)
    370 -> Ok(hashes.370)
    371 -> Ok(hashes.371)
    372 -> Ok(hashes.372)
    373 -> Ok(hashes.373)
    374 -> Ok(hashes.374)
    375 -> Ok(hashes.375)
    376 -> Ok(hashes.376)
    377 -> Ok(hashes.377)
    378 -> Ok(hashes.378)
    379 -> Ok(hashes.379)
    380 -> Ok(hashes.380)
    381 -> Ok(hashes.381)
    382 -> Ok(hashes.382)
    383 -> Ok(hashes.383)
    384 -> Ok(hashes.384)
    385 -> Ok(hashes.385)
    386 -> Ok(hashes.386)
    387 -> Ok(hashes.387)
    388 -> Ok(hashes.388)
    389 -> Ok(hashes.389)
    390 -> Ok(hashes.390)
    391 -> Ok(hashes.391)
    392 -> Ok(hashes.392)
    393 -> Ok(hashes.393)
    394 -> Ok(hashes.394)
    395 -> Ok(hashes.395)
    396 -> Ok(hashes.396)
    397 -> Ok(hashes.397)
    398 -> Ok(hashes.398)
    399 -> Ok(hashes.399)
    400 -> Ok(hashes.400)
    401 -> Ok(hashes.401)
    402 -> Ok(hashes.402)
    403 -> Ok(hashes.403)
    404 -> Ok(hashes.404)
    405 -> Ok(hashes.405)
    406 -> Ok(hashes.406)
    407 -> Ok(hashes.407)
    408 -> Ok(hashes.408)
    409 -> Ok(hashes.409)
    410 -> Ok(hashes.410)
    411 -> Ok(hashes.411)
    412 -> Ok(hashes.412)
    413 -> Ok(hashes.413)
    414 -> Ok(hashes.414)
    415 -> Ok(hashes.415)
    416 -> Ok(hashes.416)
    417 -> Ok(hashes.417)
    418 -> Ok(hashes.418)
    419 -> Ok(hashes.419)
    420 -> Ok(hashes.420)
    421 -> Ok(hashes.421)
    422 -> Ok(hashes.422)
    423 -> Ok(hashes.423)
    424 -> Ok(hashes.424)
    425 -> Ok(hashes.425)
    426 -> Ok(hashes.426)
    427 -> Ok(hashes.427)
    428 -> Ok(hashes.428)
    429 -> Ok(hashes.429)
    430 -> Ok(hashes.430)
    431 -> Ok(hashes.431)
    432 -> Ok(hashes.432)
    433 -> Ok(hashes.433)
    434 -> Ok(hashes.434)
    435 -> Ok(hashes.435)
    436 -> Ok(hashes.436)
    437 -> Ok(hashes.437)
    438 -> Ok(hashes.438)
    439 -> Ok(hashes.439)
    440 -> Ok(hashes.440)
    441 -> Ok(hashes.441)
    442 -> Ok(hashes.442)
    443 -> Ok(hashes.443)
    444 -> Ok(hashes.444)
    445 -> Ok(hashes.445)
    446 -> Ok(hashes.446)
    447 -> Ok(hashes.447)
    448 -> Ok(hashes.448)
    449 -> Ok(hashes.449)
    450 -> Ok(hashes.450)
    451 -> Ok(hashes.451)
    452 -> Ok(hashes.452)
    453 -> Ok(hashes.453)
    454 -> Ok(hashes.454)
    455 -> Ok(hashes.455)
    456 -> Ok(hashes.456)
    457 -> Ok(hashes.457)
    458 -> Ok(hashes.458)
    459 -> Ok(hashes.459)
    460 -> Ok(hashes.460)
    461 -> Ok(hashes.461)
    462 -> Ok(hashes.462)
    463 -> Ok(hashes.463)
    464 -> Ok(hashes.464)
    465 -> Ok(hashes.465)
    466 -> Ok(hashes.466)
    467 -> Ok(hashes.467)
    468 -> Ok(hashes.468)
    469 -> Ok(hashes.469)
    470 -> Ok(hashes.470)
    471 -> Ok(hashes.471)
    472 -> Ok(hashes.472)
    473 -> Ok(hashes.473)
    474 -> Ok(hashes.474)
    475 -> Ok(hashes.475)
    476 -> Ok(hashes.476)
    477 -> Ok(hashes.477)
    478 -> Ok(hashes.478)
    479 -> Ok(hashes.479)
    480 -> Ok(hashes.480)
    481 -> Ok(hashes.481)
    482 -> Ok(hashes.482)
    483 -> Ok(hashes.483)
    484 -> Ok(hashes.484)
    485 -> Ok(hashes.485)
    486 -> Ok(hashes.486)
    487 -> Ok(hashes.487)
    488 -> Ok(hashes.488)
    489 -> Ok(hashes.489)
    490 -> Ok(hashes.490)
    491 -> Ok(hashes.491)
    492 -> Ok(hashes.492)
    493 -> Ok(hashes.493)
    494 -> Ok(hashes.494)
    495 -> Ok(hashes.495)
    496 -> Ok(hashes.496)
    497 -> Ok(hashes.497)
    498 -> Ok(hashes.498)
    499 -> Ok(hashes.499)
    500 -> Ok(hashes.500)
    501 -> Ok(hashes.501)
    502 -> Ok(hashes.502)
    503 -> Ok(hashes.503)
    504 -> Ok(hashes.504)
    505 -> Ok(hashes.505)
    506 -> Ok(hashes.506)
    507 -> Ok(hashes.507)
    508 -> Ok(hashes.508)
    509 -> Ok(hashes.509)
    510 -> Ok(hashes.510)
    511 -> Ok(hashes.511)
    512 -> Ok(hashes.512)
    513 -> Ok(hashes.513)
    514 -> Ok(hashes.514)
    515 -> Ok(hashes.515)
    516 -> Ok(hashes.516)
    517 -> Ok(hashes.517)
    518 -> Ok(hashes.518)
    519 -> Ok(hashes.519)
    520 -> Ok(hashes.520)
    521 -> Ok(hashes.521)
    522 -> Ok(hashes.522)
    523 -> Ok(hashes.523)
    524 -> Ok(hashes.524)
    525 -> Ok(hashes.525)
    526 -> Ok(hashes.526)
    527 -> Ok(hashes.527)
    528 -> Ok(hashes.528)
    529 -> Ok(hashes.529)
    530 -> Ok(hashes.530)
    531 -> Ok(hashes.531)
    532 -> Ok(hashes.532)
    533 -> Ok(hashes.533)
    534 -> Ok(hashes.534)
    535 -> Ok(hashes.535)
    536 -> Ok(hashes.536)
    537 -> Ok(hashes.537)
    538 -> Ok(hashes.538)
    539 -> Ok(hashes.539)
    540 -> Ok(hashes.540)
    541 -> Ok(hashes.541)
    542 -> Ok(hashes.542)
    543 -> Ok(hashes.543)
    544 -> Ok(hashes.544)
    545 -> Ok(hashes.545)
    546 -> Ok(hashes.546)
    547 -> Ok(hashes.547)
    548 -> Ok(hashes.548)
    549 -> Ok(hashes.549)
    550 -> Ok(hashes.550)
    551 -> Ok(hashes.551)
    552 -> Ok(hashes.552)
    553 -> Ok(hashes.553)
    554 -> Ok(hashes.554)
    555 -> Ok(hashes.555)
    556 -> Ok(hashes.556)
    557 -> Ok(hashes.557)
    558 -> Ok(hashes.558)
    559 -> Ok(hashes.559)
    560 -> Ok(hashes.560)
    561 -> Ok(hashes.561)
    562 -> Ok(hashes.562)
    563 -> Ok(hashes.563)
    564 -> Ok(hashes.564)
    565 -> Ok(hashes.565)
    566 -> Ok(hashes.566)
    567 -> Ok(hashes.567)
    568 -> Ok(hashes.568)
    569 -> Ok(hashes.569)
    570 -> Ok(hashes.570)
    571 -> Ok(hashes.571)
    572 -> Ok(hashes.572)
    573 -> Ok(hashes.573)
    574 -> Ok(hashes.574)
    575 -> Ok(hashes.575)
    576 -> Ok(hashes.576)
    577 -> Ok(hashes.577)
    578 -> Ok(hashes.578)
    579 -> Ok(hashes.579)
    580 -> Ok(hashes.580)
    581 -> Ok(hashes.581)
    582 -> Ok(hashes.582)
    583 -> Ok(hashes.583)
    584 -> Ok(hashes.584)
    585 -> Ok(hashes.585)
    586 -> Ok(hashes.586)
    587 -> Ok(hashes.587)
    588 -> Ok(hashes.588)
    589 -> Ok(hashes.589)
    590 -> Ok(hashes.590)
    591 -> Ok(hashes.591)
    592 -> Ok(hashes.592)
    593 -> Ok(hashes.593)
    594 -> Ok(hashes.594)
    595 -> Ok(hashes.595)
    596 -> Ok(hashes.596)
    597 -> Ok(hashes.597)
    598 -> Ok(hashes.598)
    599 -> Ok(hashes.599)
    600 -> Ok(hashes.600)
    601 -> Ok(hashes.601)
    602 -> Ok(hashes.602)
    603 -> Ok(hashes.603)
    604 -> Ok(hashes.604)
    605 -> Ok(hashes.605)
    606 -> Ok(hashes.606)
    607 -> Ok(hashes.607)
    608 -> Ok(hashes.608)
    609 -> Ok(hashes.609)
    610 -> Ok(hashes.610)
    611 -> Ok(hashes.611)
    612 -> Ok(hashes.612)
    613 -> Ok(hashes.613)
    614 -> Ok(hashes.614)
    615 -> Ok(hashes.615)
    616 -> Ok(hashes.616)
    617 -> Ok(hashes.617)
    618 -> Ok(hashes.618)
    619 -> Ok(hashes.619)
    620 -> Ok(hashes.620)
    621 -> Ok(hashes.621)
    622 -> Ok(hashes.622)
    623 -> Ok(hashes.623)
    624 -> Ok(hashes.624)
    625 -> Ok(hashes.625)
    626 -> Ok(hashes.626)
    627 -> Ok(hashes.627)
    628 -> Ok(hashes.628)
    629 -> Ok(hashes.629)
    630 -> Ok(hashes.630)
    631 -> Ok(hashes.631)
    632 -> Ok(hashes.632)
    633 -> Ok(hashes.633)
    634 -> Ok(hashes.634)
    635 -> Ok(hashes.635)
    636 -> Ok(hashes.636)
    637 -> Ok(hashes.637)
    638 -> Ok(hashes.638)
    639 -> Ok(hashes.639)
    640 -> Ok(hashes.640)
    641 -> Ok(hashes.641)
    642 -> Ok(hashes.642)
    643 -> Ok(hashes.643)
    644 -> Ok(hashes.644)
    645 -> Ok(hashes.645)
    646 -> Ok(hashes.646)
    647 -> Ok(hashes.647)
    648 -> Ok(hashes.648)
    649 -> Ok(hashes.649)
    650 -> Ok(hashes.650)
    651 -> Ok(hashes.651)
    652 -> Ok(hashes.652)
    653 -> Ok(hashes.653)
    654 -> Ok(hashes.654)
    655 -> Ok(hashes.655)
    656 -> Ok(hashes.656)
    657 -> Ok(hashes.657)
    658 -> Ok(hashes.658)
    659 -> Ok(hashes.659)
    660 -> Ok(hashes.660)
    661 -> Ok(hashes.661)
    662 -> Ok(hashes.662)
    663 -> Ok(hashes.663)
    664 -> Ok(hashes.664)
    665 -> Ok(hashes.665)
    666 -> Ok(hashes.666)
    667 -> Ok(hashes.667)
    668 -> Ok(hashes.668)
    669 -> Ok(hashes.669)
    670 -> Ok(hashes.670)
    671 -> Ok(hashes.671)
    672 -> Ok(hashes.672)
    673 -> Ok(hashes.673)
    674 -> Ok(hashes.674)
    675 -> Ok(hashes.675)
    676 -> Ok(hashes.676)
    677 -> Ok(hashes.677)
    678 -> Ok(hashes.678)
    679 -> Ok(hashes.679)
    680 -> Ok(hashes.680)
    681 -> Ok(hashes.681)
    682 -> Ok(hashes.682)
    683 -> Ok(hashes.683)
    684 -> Ok(hashes.684)
    685 -> Ok(hashes.685)
    686 -> Ok(hashes.686)
    687 -> Ok(hashes.687)
    688 -> Ok(hashes.688)
    689 -> Ok(hashes.689)
    690 -> Ok(hashes.690)
    691 -> Ok(hashes.691)
    692 -> Ok(hashes.692)
    693 -> Ok(hashes.693)
    694 -> Ok(hashes.694)
    695 -> Ok(hashes.695)
    696 -> Ok(hashes.696)
    697 -> Ok(hashes.697)
    698 -> Ok(hashes.698)
    699 -> Ok(hashes.699)
    700 -> Ok(hashes.700)
    701 -> Ok(hashes.701)
    702 -> Ok(hashes.702)
    703 -> Ok(hashes.703)
    704 -> Ok(hashes.704)
    705 -> Ok(hashes.705)
    706 -> Ok(hashes.706)
    707 -> Ok(hashes.707)
    708 -> Ok(hashes.708)
    709 -> Ok(hashes.709)
    710 -> Ok(hashes.710)
    711 -> Ok(hashes.711)
    712 -> Ok(hashes.712)
    713 -> Ok(hashes.713)
    714 -> Ok(hashes.714)
    715 -> Ok(hashes.715)
    716 -> Ok(hashes.716)
    717 -> Ok(hashes.717)
    718 -> Ok(hashes.718)
    719 -> Ok(hashes.719)
    720 -> Ok(hashes.720)
    721 -> Ok(hashes.721)
    722 -> Ok(hashes.722)
    723 -> Ok(hashes.723)
    724 -> Ok(hashes.724)
    725 -> Ok(hashes.725)
    726 -> Ok(hashes.726)
    727 -> Ok(hashes.727)
    728 -> Ok(hashes.728)
    729 -> Ok(hashes.729)
    730 -> Ok(hashes.730)
    731 -> Ok(hashes.731)
    732 -> Ok(hashes.732)
    733 -> Ok(hashes.733)
    734 -> Ok(hashes.734)
    735 -> Ok(hashes.735)
    736 -> Ok(hashes.736)
    737 -> Ok(hashes.737)
    738 -> Ok(hashes.738)
    739 -> Ok(hashes.739)
    740 -> Ok(hashes.740)
    741 -> Ok(hashes.741)
    742 -> Ok(hashes.742)
    743 -> Ok(hashes.743)
    744 -> Ok(hashes.744)
    745 -> Ok(hashes.745)
    746 -> Ok(hashes.746)
    747 -> Ok(hashes.747)
    748 -> Ok(hashes.748)
    749 -> Ok(hashes.749)
    750 -> Ok(hashes.750)
    751 -> Ok(hashes.751)
    752 -> Ok(hashes.752)
    753 -> Ok(hashes.753)
    754 -> Ok(hashes.754)
    755 -> Ok(hashes.755)
    756 -> Ok(hashes.756)
    757 -> Ok(hashes.757)
    758 -> Ok(hashes.758)
    759 -> Ok(hashes.759)
    760 -> Ok(hashes.760)
    761 -> Ok(hashes.761)
    762 -> Ok(hashes.762)
    763 -> Ok(hashes.763)
    764 -> Ok(hashes.764)
    765 -> Ok(hashes.765)
    766 -> Ok(hashes.766)
    767 -> Ok(hashes.767)
    768 -> Ok(hashes.768)
    769 -> Ok(hashes.769)
    770 -> Ok(hashes.770)
    771 -> Ok(hashes.771)
    772 -> Ok(hashes.772)
    773 -> Ok(hashes.773)
    774 -> Ok(hashes.774)
    775 -> Ok(hashes.775)
    776 -> Ok(hashes.776)
    777 -> Ok(hashes.777)
    778 -> Ok(hashes.778)
    779 -> Ok(hashes.779)
    780 -> Ok(hashes.780)
    _ -> Error(Nil)
  }
}

// We can just use a pre-computed table of hashes
// There are 64 * 12 + 1
// We use tuples to have constant time indexing
const hashes = #(
  0x9D39247E33776D41,
  0x2AF7398005AAA5C7,
  0x44DB015024623547,
  0x9C15F73E62A76AE2,
  0x75834465489C0C89,
  0x3290AC3A203001BF,
  0x0FBBAD1F61042279,
  0xE83A908FF2FB60CA,
  0x0D7E765D58755C10,
  0x1A083822CEAFE02D,
  0x9605D5F0E25EC3B0,
  0xD021FF5CD13A2ED5,
  0x40BDF15D4A672E32,
  0x011355146FD56395,
  0x5DB4832046F3D9E5,
  0x239F8B2D7FF719CC,
  0x05D1A1AE85B49AA1,
  0x679F848F6E8FC971,
  0x7449BBFF801FED0B,
  0x7D11CDB1C3B7ADF0,
  0x82C7709E781EB7CC,
  0xF3218F1C9510786C,
  0x331478F3AF51BBE6,
  0x4BB38DE5E7219443,
  0xAA649C6EBCFD50FC,
  0x8DBD98A352AFD40B,
  0x87D2074B81D79217,
  0x19F3C751D3E92AE1,
  0xB4AB30F062B19ABF,
  0x7B0500AC42047AC4,
  0xC9452CA81A09D85D,
  0x24AA6C514DA27500,
  0x4C9F34427501B447,
  0x14A68FD73C910841,
  0xA71B9B83461CBD93,
  0x03488B95B0F1850F,
  0x637B2B34FF93C040,
  0x09D1BC9A3DD90A94,
  0x3575668334A1DD3B,
  0x735E2B97A4C45A23,
  0x18727070F1BD400B,
  0x1FCBACD259BF02E7,
  0xD310A7C2CE9B6555,
  0xBF983FE0FE5D8244,
  0x9F74D14F7454A824,
  0x51EBDC4AB9BA3035,
  0x5C82C505DB9AB0FA,
  0xFCF7FE8A3430B241,
  0x3253A729B9BA3DDE,
  0x8C74C368081B3075,
  0xB9BC6C87167C33E7,
  0x7EF48F2B83024E20,
  0x11D505D4C351BD7F,
  0x6568FCA92C76A243,
  0x4DE0B0F40F32A7B8,
  0x96D693460CC37E5D,
  0x42E240CB63689F2F,
  0x6D2BDCDAE2919661,
  0x42880B0236E4D951,
  0x5F0F4A5898171BB6,
  0x39F890F579F92F88,
  0x93C5B5F47356388B,
  0x63DC359D8D231B78,
  0xEC16CA8AEA98AD76,
  0x5355F900C2A82DC7,
  0x07FB9F855A997142,
  0x5093417AA8A7ED5E,
  0x7BCBC38DA25A7F3C,
  0x19FC8A768CF4B6D4,
  0x637A7780DECFC0D9,
  0x8249A47AEE0E41F7,
  0x79AD695501E7D1E8,
  0x14ACBAF4777D5776,
  0xF145B6BECCDEA195,
  0xDABF2AC8201752FC,
  0x24C3C94DF9C8D3F6,
  0xBB6E2924F03912EA,
  0x0CE26C0B95C980D9,
  0xA49CD132BFBF7CC4,
  0xE99D662AF4243939,
  0x27E6AD7891165C3F,
  0x8535F040B9744FF1,
  0x54B3F4FA5F40D873,
  0x72B12C32127FED2B,
  0xEE954D3C7B411F47,
  0x9A85AC909A24EAA1,
  0x70AC4CD9F04F21F5,
  0xF9B89D3E99A075C2,
  0x87B3E2B2B5C907B1,
  0xA366E5B8C54F48B8,
  0xAE4A9346CC3F7CF2,
  0x1920C04D47267BBD,
  0x87BF02C6B49E2AE9,
  0x092237AC237F3859,
  0xFF07F64EF8ED14D0,
  0x8DE8DCA9F03CC54E,
  0x9C1633264DB49C89,
  0xB3F22C3D0B0B38ED,
  0x390E5FB44D01144B,
  0x5BFEA5B4712768E9,
  0x1E1032911FA78984,
  0x9A74ACB964E78CB3,
  0x4F80F7A035DAFB04,
  0x6304D09A0B3738C4,
  0x2171E64683023A08,
  0x5B9B63EB9CEFF80C,
  0x506AACF489889342,
  0x1881AFC9A3A701D6,
  0x6503080440750644,
  0xDFD395339CDBF4A7,
  0xEF927DBCF00C20F2,
  0x7B32F7D1E03680EC,
  0xB9FD7620E7316243,
  0x05A7E8A57DB91B77,
  0xB5889C6E15630A75,
  0x4A750A09CE9573F7,
  0xCF464CEC899A2F8A,
  0xF538639CE705B824,
  0x3C79A0FF5580EF7F,
  0xEDE6C87F8477609D,
  0x799E81F05BC93F31,
  0x86536B8CF3428A8C,
  0x97D7374C60087B73,
  0xA246637CFF328532,
  0x043FCAE60CC0EBA0,
  0x920E449535DD359E,
  0x70EB093B15B290CC,
  0x73A1921916591CBD,
  0x56436C9FE1A1AA8D,
  0xEFAC4B70633B8F81,
  0xBB215798D45DF7AF,
  0x45F20042F24F1768,
  0x930F80F4E8EB7462,
  0xFF6712FFCFD75EA1,
  0xAE623FD67468AA70,
  0xDD2C5BC84BC8D8FC,
  0x7EED120D54CF2DD9,
  0x22FE545401165F1C,
  0xC91800E98FB99929,
  0x808BD68E6AC10365,
  0xDEC468145B7605F6,
  0x1BEDE3A3AEF53302,
  0x43539603D6C55602,
  0xAA969B5C691CCB7A,
  0xA87832D392EFEE56,
  0x65942C7B3C7E11AE,
  0xDED2D633CAD004F6,
  0x21F08570F420E565,
  0xB415938D7DA94E3C,
  0x91B859E59ECB6350,
  0x10CFF333E0ED804A,
  0x28AED140BE0BB7DD,
  0xC5CC1D89724FA456,
  0x5648F680F11A2741,
  0x2D255069F0B7DAB3,
  0x9BC5A38EF729ABD4,
  0xEF2F054308F6A2BC,
  0xAF2042F5CC5C2858,
  0x480412BAB7F5BE2A,
  0xAEF3AF4A563DFE43,
  0x19AFE59AE451497F,
  0x52593803DFF1E840,
  0xF4F076E65F2CE6F0,
  0x11379625747D5AF3,
  0xBCE5D2248682C115,
  0x9DA4243DE836994F,
  0x066F70B33FE09017,
  0x4DC4DE189B671A1C,
  0x51039AB7712457C3,
  0xC07A3F80C31FB4B4,
  0xB46EE9C5E64A6E7C,
  0xB3819A42ABE61C87,
  0x21A007933A522A20,
  0x2DF16F761598AA4F,
  0x763C4A1371B368FD,
  0xF793C46702E086A0,
  0xD7288E012AEB8D31,
  0xDE336A2A4BC1C44B,
  0x0BF692B38D079F23,
  0x2C604A7A177326B3,
  0x4850E73E03EB6064,
  0xCFC447F1E53C8E1B,
  0xB05CA3F564268D99,
  0x9AE182C8BC9474E8,
  0xA4FC4BD4FC5558CA,
  0xE755178D58FC4E76,
  0x69B97DB1A4C03DFE,
  0xF9B5B7C4ACC67C96,
  0xFC6A82D64B8655FB,
  0x9C684CB6C4D24417,
  0x8EC97D2917456ED0,
  0x6703DF9D2924E97E,
  0xC547F57E42A7444E,
  0x78E37644E7CAD29E,
  0xFE9A44E9362F05FA,
  0x08BD35CC38336615,
  0x9315E5EB3A129ACE,
  0x94061B871E04DF75,
  0xDF1D9F9D784BA010,
  0x3BBA57B68871B59D,
  0xD2B7ADEEDED1F73F,
  0xF7A255D83BC373F8,
  0xD7F4F2448C0CEB81,
  0xD95BE88CD210FFA7,
  0x336F52F8FF4728E7,
  0xA74049DAC312AC71,
  0xA2F61BB6E437FDB5,
  0x4F2A5CB07F6A35B3,
  0x87D380BDA5BF7859,
  0x16B9F7E06C453A21,
  0x7BA2484C8A0FD54E,
  0xF3A678CAD9A2E38C,
  0x39B0BF7DDE437BA2,
  0xFCAF55C1BF8A4424,
  0x18FCF680573FA594,
  0x4C0563B89F495AC3,
  0x40E087931A00930D,
  0x8CFFA9412EB642C1,
  0x68CA39053261169F,
  0x7A1EE967D27579E2,
  0x9D1D60E5076F5B6F,
  0x3810E399B6F65BA2,
  0x32095B6D4AB5F9B1,
  0x35CAB62109DD038A,
  0xA90B24499FCFAFB1,
  0x77A225A07CC2C6BD,
  0x513E5E634C70E331,
  0x4361C0CA3F692F12,
  0xD941ACA44B20A45B,
  0x528F7C8602C5807B,
  0x52AB92BEB9613989,
  0x9D1DFA2EFC557F73,
  0x722FF175F572C348,
  0x1D1260A51107FE97,
  0x7A249A57EC0C9BA2,
  0x04208FE9E8F7F2D6,
  0x5A110C6058B920A0,
  0x0CD9A497658A5698,
  0x56FD23C8F9715A4C,
  0x284C847B9D887AAE,
  0x04FEABFBBDB619CB,
  0x742E1E651C60BA83,
  0x9A9632E65904AD3C,
  0x881B82A13B51B9E2,
  0x506E6744CD974924,
  0xB0183DB56FFC6A79,
  0x0ED9B915C66ED37E,
  0x5E11E86D5873D484,
  0xF678647E3519AC6E,
  0x1B85D488D0F20CC5,
  0xDAB9FE6525D89021,
  0x0D151D86ADB73615,
  0xA865A54EDCC0F019,
  0x93C42566AEF98FFB,
  0x99E7AFEABE000731,
  0x48CBFF086DDF285A,
  0x7F9B6AF1EBF78BAF,
  0x58627E1A149BBA21,
  0x2CD16E2ABD791E33,
  0xD363EFF5F0977996,
  0x0CE2A38C344A6EED,
  0x1A804AADB9CFA741,
  0x907F30421D78C5DE,
  0x501F65EDB3034D07,
  0x37624AE5A48FA6E9,
  0x957BAF61700CFF4E,
  0x3A6C27934E31188A,
  0xD49503536ABCA345,
  0x088E049589C432E0,
  0xF943AEE7FEBF21B8,
  0x6C3B8E3E336139D3,
  0x364F6FFA464EE52E,
  0xD60F6DCEDC314222,
  0x56963B0DCA418FC0,
  0x16F50EDF91E513AF,
  0xEF1955914B609F93,
  0x565601C0364E3228,
  0xECB53939887E8175,
  0xBAC7A9A18531294B,
  0xB344C470397BBA52,
  0x65D34954DAF3CEBD,
  0xB4B81B3FA97511E2,
  0xB422061193D6F6A7,
  0x071582401C38434D,
  0x7A13F18BBEDC4FF5,
  0xBC4097B116C524D2,
  0x59B97885E2F2EA28,
  0x99170A5DC3115544,
  0x6F423357E7C6A9F9,
  0x325928EE6E6F8794,
  0xD0E4366228B03343,
  0x565C31F7DE89EA27,
  0x30F5611484119414,
  0xD873DB391292ED4F,
  0x7BD94E1D8E17DEBC,
  0xC7D9F16864A76E94,
  0x947AE053EE56E63C,
  0xC8C93882F9475F5F,
  0x3A9BF55BA91F81CA,
  0xD9A11FBB3D9808E4,
  0x0FD22063EDC29FCA,
  0xB3F256D8ACA0B0B9,
  0xB03031A8B4516E84,
  0x35DD37D5871448AF,
  0xE9F6082B05542E4E,
  0xEBFAFA33D7254B59,
  0x9255ABB50D532280,
  0xB9AB4CE57F2D34F3,
  0x693501D628297551,
  0xC62C58F97DD949BF,
  0xCD454F8F19C5126A,
  0xBBE83F4ECC2BDECB,
  0xDC842B7E2819E230,
  0xBA89142E007503B8,
  0xA3BC941D0A5061CB,
  0xE9F6760E32CD8021,
  0x09C7E552BC76492F,
  0x852F54934DA55CC9,
  0x8107FCCF064FCF56,
  0x098954D51FFF6580,
  0x23B70EDB1955C4BF,
  0xC330DE426430F69D,
  0x4715ED43E8A45C0A,
  0xA8D7E4DAB780A08D,
  0x0572B974F03CE0BB,
  0xB57D2E985E1419C7,
  0xE8D9ECBE2CF3D73F,
  0x2FE4B17170E59750,
  0x11317BA87905E790,
  0x7FBF21EC8A1F45EC,
  0x1725CABFCB045B00,
  0x964E915CD5E2B207,
  0x3E2B8BCBF016D66D,
  0xBE7444E39328A0AC,
  0xF85B2B4FBCDE44B7,
  0x49353FEA39BA63B1,
  0x1DD01AAFCD53486A,
  0x1FCA8A92FD719F85,
  0xFC7C95D827357AFA,
  0x18A6A990C8B35EBD,
  0xCCCB7005C6B9C28D,
  0x3BDBB92C43B17F26,
  0xAA70B5B4F89695A2,
  0xE94C39A54A98307F,
  0xB7A0B174CFF6F36E,
  0xD4DBA84729AF48AD,
  0x2E18BC1AD9704A68,
  0x2DE0966DAF2F8B1C,
  0xB9C11D5B1E43A07E,
  0x64972D68DEE33360,
  0x94628D38D0C20584,
  0xDBC0D2B6AB90A559,
  0xD2733C4335C6A72F,
  0x7E75D99D94A70F4D,
  0x6CED1983376FA72B,
  0x97FCAACBF030BC24,
  0x7B77497B32503B12,
  0x8547EDDFB81CCB94,
  0x79999CDFF70902CB,
  0xCFFE1939438E9B24,
  0x829626E3892D95D7,
  0x92FAE24291F2B3F1,
  0x63E22C147B9C3403,
  0xC678B6D860284A1C,
  0x5873888850659AE7,
  0x0981DCD296A8736D,
  0x9F65789A6509A440,
  0x9FF38FED72E9052F,
  0xE479EE5B9930578C,
  0xE7F28ECD2D49EECD,
  0x56C074A581EA17FE,
  0x5544F7D774B14AEF,
  0x7B3F0195FC6F290F,
  0x12153635B2C0CF57,
  0x7F5126DBBA5E0CA7,
  0x7A76956C3EAFB413,
  0x3D5774A11D31AB39,
  0x8A1B083821F40CB4,
  0x7B4A38E32537DF62,
  0x950113646D1D6E03,
  0x4DA8979A0041E8A9,
  0x3BC36E078F7515D7,
  0x5D0A12F27AD310D1,
  0x7F9D1A2E1EBE1327,
  0xDA3A361B1C5157B1,
  0xDCDD7D20903D0C25,
  0x36833336D068F707,
  0xCE68341F79893389,
  0xAB9090168DD05F34,
  0x43954B3252DC25E5,
  0xB438C2B67F98E5E9,
  0x10DCD78E3851A492,
  0xDBC27AB5447822BF,
  0x9B3CDB65F82CA382,
  0xB67B7896167B4C84,
  0xBFCED1B0048EAC50,
  0xA9119B60369FFEBD,
  0x1FFF7AC80904BF45,
  0xAC12FB171817EEE7,
  0xAF08DA9177DDA93D,
  0x1B0CAB936E65C744,
  0xB559EB1D04E5E932,
  0xC37B45B3F8D6F2BA,
  0xC3A9DC228CAAC9E9,
  0xF3B8B6675A6507FF,
  0x9FC477DE4ED681DA,
  0x67378D8ECCEF96CB,
  0x6DD856D94D259236,
  0xA319CE15B0B4DB31,
  0x073973751F12DD5E,
  0x8A8E849EB32781A5,
  0xE1925C71285279F5,
  0x74C04BF1790C0EFE,
  0x4DDA48153C94938A,
  0x9D266D6A1CC0542C,
  0x7440FB816508C4FE,
  0x13328503DF48229F,
  0xD6BF7BAEE43CAC40,
  0x4838D65F6EF6748F,
  0x1E152328F3318DEA,
  0x8F8419A348F296BF,
  0x72C8834A5957B511,
  0xD7A023A73260B45C,
  0x94EBC8ABCFB56DAE,
  0x9FC10D0F989993E0,
  0xDE68A2355B93CAE6,
  0xA44CFE79AE538BBE,
  0x9D1D84FCCE371425,
  0x51D2B1AB2DDFB636,
  0x2FD7E4B9E72CD38C,
  0x65CA5B96B7552210,
  0xDD69A0D8AB3B546D,
  0x604D51B25FBF70E2,
  0x73AA8A564FB7AC9E,
  0x1A8C1E992B941148,
  0xAAC40A2703D9BEA0,
  0x764DBEAE7FA4F3A6,
  0x1E99B96E70A9BE8B,
  0x2C5E9DEB57EF4743,
  0x3A938FEE32D29981,
  0x26E6DB8FFDF5ADFE,
  0x469356C504EC9F9D,
  0xC8763C5B08D1908C,
  0x3F6C6AF859D80055,
  0x7F7CC39420A3A545,
  0x9BFB227EBDF4C5CE,
  0x89039D79D6FC5C5C,
  0x8FE88B57305E2AB6,
  0xA09E8C8C35AB96DE,
  0xFA7E393983325753,
  0xD6B6D0ECC617C699,
  0xDFEA21EA9E7557E3,
  0xB67C1FA481680AF8,
  0xCA1E3785A9E724E5,
  0x1CFC8BED0D681639,
  0xD18D8549D140CAEA,
  0x4ED0FE7E9DC91335,
  0xE4DBF0634473F5D2,
  0x1761F93A44D5AEFE,
  0x53898E4C3910DA55,
  0x734DE8181F6EC39A,
  0x2680B122BAA28D97,
  0x298AF231C85BAFAB,
  0x7983EED3740847D5,
  0x66C1A2A1A60CD889,
  0x9E17E49642A3E4C1,
  0xEDB454E7BADC0805,
  0x50B704CAB602C329,
  0x4CC317FB9CDDD023,
  0x66B4835D9EAFEA22,
  0x219B97E26FFC81BD,
  0x261E4E4C0A333A9D,
  0x1FE2CCA76517DB90,
  0xD7504DFA8816EDBB,
  0xB9571FA04DC089C8,
  0x1DDC0325259B27DE,
  0xCF3F4688801EB9AA,
  0xF4F5D05C10CAB243,
  0x38B6525C21A42B0E,
  0x36F60E2BA4FA6800,
  0xEB3593803173E0CE,
  0x9C4CD6257C5A3603,
  0xAF0C317D32ADAA8A,
  0x258E5A80C7204C4B,
  0x8B889D624D44885D,
  0xF4D14597E660F855,
  0xD4347F66EC8941C3,
  0xE699ED85B0DFB40D,
  0x2472F6207C2D0484,
  0xC2A1E7B5B459AEB5,
  0xAB4F6451CC1D45EC,
  0x63767572AE3D6174,
  0xA59E0BD101731A28,
  0x116D0016CB948F09,
  0x2CF9C8CA052F6E9F,
  0x0B090A7560A968E3,
  0xABEEDDB2DDE06FF1,
  0x58EFC10B06A2068D,
  0xC6E57A78FBD986E0,
  0x2EAB8CA63CE802D7,
  0x14A195640116F336,
  0x7C0828DD624EC390,
  0xD74BBE77E6116AC7,
  0x804456AF10F5FB53,
  0xEBE9EA2ADF4321C7,
  0x03219A39EE587A30,
  0x49787FEF17AF9924,
  0xA1E9300CD8520548,
  0x5B45E522E4B1B4EF,
  0xB49C3B3995091A36,
  0xD4490AD526F14431,
  0x12A8F216AF9418C2,
  0x001F837CC7350524,
  0x1877B51E57A764D5,
  0xA2853B80F17F58EE,
  0x993E1DE72D36D310,
  0xB3598080CE64A656,
  0x252F59CF0D9F04BB,
  0xD23C8E176D113600,
  0x1BDA0492E7E4586E,
  0x21E0BD5026C619BF,
  0x3B097ADAF088F94E,
  0x8D14DEDB30BE846E,
  0xF95CFFA23AF5F6F4,
  0x3871700761B3F743,
  0xCA672B91E9E4FA16,
  0x64C8E531BFF53B55,
  0x241260ED4AD1E87D,
  0x106C09B972D2E822,
  0x7FBA195410E5CA30,
  0x7884D9BC6CB569D8,
  0x0647DFEDCD894A29,
  0x63573FF03E224774,
  0x4FC8E9560F91B123,
  0x1DB956E450275779,
  0xB8D91274B9E9D4FB,
  0xA2EBEE47E2FBFCE1,
  0xD9F1F30CCD97FB09,
  0xEFED53D75FD64E6B,
  0x2E6D02C36017F67F,
  0xA9AA4D20DB084E9B,
  0xB64BE8D8B25396C1,
  0x70CB6AF7C2D5BCF0,
  0x98F076A4F7A2322E,
  0xBF84470805E69B5F,
  0x94C3251F06F90CF3,
  0x3E003E616A6591E9,
  0xB925A6CD0421AFF3,
  0x61BDD1307C66E300,
  0xBF8D5108E27E0D48,
  0x240AB57A8B888B20,
  0xFC87614BAF287E07,
  0xEF02CDD06FFDB432,
  0xA1082C0466DF6C0A,
  0x8215E577001332C8,
  0xD39BB9C3A48DB6CF,
  0x2738259634305C14,
  0x61CF4F94C97DF93D,
  0x1B6BACA2AE4E125B,
  0x758F450C88572E0B,
  0x959F587D507A8359,
  0xB063E962E045F54D,
  0x60E8ED72C0DFF5D1,
  0x7B64978555326F9F,
  0xFD080D236DA814BA,
  0x8C90FD9B083F4558,
  0x106F72FE81E2C590,
  0x7976033A39F7D952,
  0xA4EC0132764CA04B,
  0x733EA705FAE4FA77,
  0xB4D8F77BC3E56167,
  0x9E21F4F903B33FD9,
  0x9D765E419FB69F6D,
  0xD30C088BA61EA5EF,
  0x5D94337FBFAF7F5B,
  0x1A4E4822EB4D7A59,
  0x6FFE73E81B637FB3,
  0xDDF957BC36D8B9CA,
  0x64D0E29EEA8838B3,
  0x08DD9BDFD96B9F63,
  0x087E79E5A57D1D13,
  0xE328E230E3E2B3FB,
  0x1C2559E30F0946BE,
  0x720BF5F26F4D2EAA,
  0xB0774D261CC609DB,
  0x443F64EC5A371195,
  0x4112CF68649A260E,
  0xD813F2FAB7F5C5CA,
  0x660D3257380841EE,
  0x59AC2C7873F910A3,
  0xE846963877671A17,
  0x93B633ABFA3469F8,
  0xC0C0F5A60EF4CDCF,
  0xCAF21ECD4377B28C,
  0x57277707199B8175,
  0x506C11B9D90E8B1D,
  0xD83CC2687A19255F,
  0x4A29C6465A314CD1,
  0xED2DF21216235097,
  0xB5635C95FF7296E2,
  0x22AF003AB672E811,
  0x52E762596BF68235,
  0x9AEBA33AC6ECC6B0,
  0x944F6DE09134DFB6,
  0x6C47BEC883A7DE39,
  0x6AD047C430A12104,
  0xA5B1CFDBA0AB4067,
  0x7C45D833AFF07862,
  0x5092EF950A16DA0B,
  0x9338E69C052B8E7B,
  0x455A4B4CFE30E3F5,
  0x6B02E63195AD0CF8,
  0x6B17B224BAD6BF27,
  0xD1E0CCD25BB9C169,
  0xDE0C89A556B9AE70,
  0x50065E535A213CF6,
  0x9C1169FA2777B874,
  0x78EDEFD694AF1EED,
  0x6DC93D9526A50E68,
  0xEE97F453F06791ED,
  0x32AB0EDB696703D3,
  0x3A6853C7E70757A7,
  0x31865CED6120F37D,
  0x67FEF95D92607890,
  0x1F2B1D1F15F6DC9C,
  0xB69E38A8965C6B65,
  0xAA9119FF184CCCF4,
  0xF43C732873F24C13,
  0xFB4A3D794A9A80D2,
  0x3550C2321FD6109C,
  0x371F77E76BB8417E,
  0x6BFA9AAE5EC05779,
  0xCD04F3FF001A4778,
  0xE3273522064480CA,
  0x9F91508BFFCFC14A,
  0x049A7F41061A9E60,
  0xFCB6BE43A9F2FE9B,
  0x08DE8A1C7797DA9B,
  0x8F9887E6078735A1,
  0xB5B4071DBFC73A66,
  0x230E343DFBA08D33,
  0x43ED7F5A0FAE657D,
  0x3A88A0FBBCB05C63,
  0x21874B8B4D2DBC4F,
  0x1BDEA12E35F6A8C9,
  0x53C065C6C8E63528,
  0xE34A1D250E7A8D6B,
  0xD6B04D3B7651DD7E,
  0x5E90277E7CB39E2D,
  0x2C046F22062DC67D,
  0xB10BB459132D0A26,
  0x3FA9DDFB67E2F199,
  0x0E09B88E1914F7AF,
  0x10E8B35AF3EEAB37,
  0x9EEDECA8E272B933,
  0xD4C718BC4AE8AE5F,
  0x81536D601170FC20,
  0x91B534F885818A06,
  0xEC8177F83F900978,
  0x190E714FADA5156E,
  0xB592BF39B0364963,
  0x89C350C893AE7DC1,
  0xAC042E70F8B383F2,
  0xB49B52E587A1EE60,
  0xFB152FE3FF26DA89,
  0x3E666E6F69AE2C15,
  0x3B544EBE544C19F9,
  0xE805A1E290CF2456,
  0x24B33C9D7ED25117,
  0xE74733427B72F0C1,
  0x0A804D18B7097475,
  0x57E3306D881EDB4F,
  0x4AE7D6A36EB5DBCB,
  0x2D8D5432157064C8,
  0xD1E649DE1E7F268B,
  0x8A328A1CEDFE552C,
  0x07A3AEC79624C7DA,
  0x84547DDC3E203C94,
  0x990A98FD5071D263,
  0x1A4FF12616EEFC89,
  0xF6F7FD1431714200,
  0x30C05B1BA332F41C,
  0x8D2636B81555A786,
  0x46C9FEB55D120902,
  0xCCEC0A73B49C9921,
  0x4E9D2827355FC492,
  0x19EBB029435DCB0F,
  0x4659D2B743848A2C,
  0x963EF2C96B33BE31,
  0x74F85198B05A2E7D,
  0x5A0F544DD2B1FB18,
  0x03727073C2E134B1,
  0xC7F6AA2DE59AEA61,
  0x352787BAA0D7C22F,
  0x9853EAB63B5E0B35,
  0xABBDCDD7ED5C0860,
  0xCF05DAF5AC8D77B0,
  0x49CAD48CEBF4A71E,
  0x7A4C10EC2158C4A6,
  0xD9E92AA246BF719E,
  0x13AE978D09FE5557,
  0x730499AF921549FF,
  0x4E4B705B92903BA4,
  0xFF577222C14F0A3A,
  0x55B6344CF97AAFAE,
  0xB862225B055B6960,
  0xCAC09AFBDDD2CDB4,
  0xDAF8E9829FE96B5F,
  0xB5FDFC5D3132C498,
  0x310CB380DB6F7503,
  0xE87FBB46217A360E,
  0x2102AE466EBB1148,
  0xF8549E1A3AA5E00D,
  0x07A69AFDCC42261A,
  0xC4C118BFE78FEAAE,
  0xF9F4892ED96BD438,
  0x1AF3DBE25D8F45DA,
  0xF5B4B0B0D2DEEEB4,
  0x962ACEEFA82E1C84,
  0x046E3ECAAF453CE9,
  0xF05D129681949A4C,
  0x964781CE734B3C84,
  0x9C2ED44081CE5FBD,
  0x522E23F3925E319E,
  0x177E00F9FC32F791,
  0x2BC60A63A6F3B3F2,
  0x222BBFAE61725606,
  0x486289DDCC3D6780,
  0x7DC7785B8EFDFC80,
  0x8AF38731C02BA980,
  0x1FAB64EA29A2DDF7,
  0xE4D9429322CD065A,
  0x9DA058C67844F20C,
  0x24C0E332B70019B0,
  0x233003B5A6CFE6AD,
  0xD586BD01C5C217F6,
  0x5E5637885F29BC2B,
  0x7EBA726D8C94094B,
  0x0A56A5F0BFE39272,
  0xD79476A84EE20D06,
  0x9E4C1269BAA4BF37,
  0x17EFEE45B0DEE640,
  0x1D95B0A5FCF90BC6,
  0x93CBE0B699C2585D,
  0x65FA4F227A2B6D79,
  0xD5F9E858292504D5,
  0xC2B5A03F71471A6F,
  0x59300222B4561E00,
  0xCE2F8642CA0712DC,
  0x7CA9723FBB2E8988,
  0x2785338347F2BA08,
  0xC61BB3A141E50E8C,
  0x150F361DAB9DEC26,
  0x9F6A419D382595F4,
  0x64A53DC924FE7AC9,
  0x142DE49FFF7A7C3D,
  0x0C335248857FA9E7,
  0x0A9C32D5EAE45305,
  0xE6C42178C4BBB92E,
  0x71F1CE2490D20B07,
  0xF1BCC3D275AFE51A,
  0xE728E8C83C334074,
  0x96FBF83A12884624,
  0x81A1549FD6573DA5,
  0x5FA7867CAF35E149,
  0x56986E2EF3ED091B,
  0x917F1DD5F8886C61,
  0xD20D8C88C8FFE65F,
  0x31D71DCE64B2C310,
  0xF165B587DF898190,
  0xA57E6339DD2CF3A0,
  0x1EF6E6DBB1961EC9,
  0x70CC73D90BC26E24,
  0xE21A6B35DF0C3AD7,
  0x003A93D8B2806962,
  0x1C99DED33CB890A1,
  0xCF3145DE0ADD4289,
  0xD0E4427A5514FB72,
  0x77C621CC9FB3A483,
  0x67A34DAC4356550B,
  0xF8D626AAAF278509,
)
