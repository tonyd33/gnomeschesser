import chess/bitboard
import chess/constants/zobrist
import chess/game/castle.{
  type Castle, type CastlingAvailability, CastlingAvailability, KingSide,
  QueenSide,
}
import chess/move
import chess/move/disambiguation
import chess/piece
import chess/player.{Black, White}
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

/// 0: board: Dict(square.Square, piece.Piece),
/// 1: bitboard: bitboard.GameBitboard,
/// 2: active_color: player.Player,
/// 3: castling_availability: CastlingAvailability,
/// 4: en_passant_target_square: Option(#(player.Player, square.Square)),
/// 5: halfmove_clock: Int,
/// 6: fullmove_number: Int,
/// 7: hash: Hash,
/// 8: en_passant_hash: Hash,
///
/// TODO: Only store en_passant_target_square if there's actually a piece
/// to take it, and then get rid of en_passant_hash
///
pub type Game =
  #(
    Dict(square.Square, piece.Piece),
    bitboard.GameBitboard,
    player.Player,
    CastlingAvailability,
    Option(#(player.Player, square.Square)),
    Int,
    Int,
    Hash,
    Hash,
  )

pub fn get_game_bitboard(game: Game) {
  game.1
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
                True -> Black
                False -> White
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
    |> list.fold(
      castle.no_castling_availability,
      fn(castling_availability, char) {
        case char {
          "K" ->
            CastlingAvailability(..castling_availability, white_kingside: True)
          "Q" ->
            CastlingAvailability(..castling_availability, white_queenside: True)
          "k" ->
            CastlingAvailability(..castling_availability, black_kingside: True)
          "q" ->
            CastlingAvailability(..castling_availability, black_queenside: True)
          _ -> castling_availability
        }
      },
    )

  let active_color = case active_color {
    "w" -> White
    "b" -> Black
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
  let en_passant_hash =
    ep_hash(active_color, bitboard, en_passant_target_square)

  #(
    board,
    bitboard,
    active_color,
    castling_availability,
    en_passant_target_square,
    halfmove_clock,
    fullmove_number,
    hash,
    en_passant_hash,
  )
  |> Ok
}

pub fn turn(game: Game) -> player.Player {
  game.2
}

pub fn board(game: Game) -> Dict(square.Square, piece.Piece) {
  game.0
}

pub fn hash(game: Game) -> Hash {
  game.7
}

pub fn castling_availability(game: Game) -> List(#(player.Player, Castle)) {
  let x = []
  let x = case { game.3 }.black_queenside {
    True -> [#(Black, QueenSide), ..x]
    False -> x
  }
  let x = case { game.3 }.black_kingside {
    True -> [#(Black, KingSide), ..x]
    False -> x
  }
  let x = case { game.3 }.white_queenside {
    True -> [#(White, QueenSide), ..x]
    False -> x
  }
  let x = case { game.3 }.white_kingside {
    True -> [#(White, KingSide), ..x]
    False -> x
  }
  x
}

pub fn en_passant_target_square(
  game: Game,
) -> Option(#(player.Player, square.Square)) {
  game.4
}

pub fn halfmove_clock(game: Game) -> Int {
  game.5
}

pub fn fullmove_number(game: Game) -> Int {
  game.6
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

        let _piece_string = case dict.has_key(game.0, actual_square) {
          True -> {
            dict.get(game.0, actual_square)
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

  let halfmove_clock_string = int.to_string(game.5)
  let fullmove_number_string = int.to_string(game.6)
  let castling_rights_string =
    castling_availability(game)
    |> list.filter_map(fn(val) {
      case val {
        #(White, KingSide) -> Ok("K")
        #(White, QueenSide) -> Ok("Q")
        #(Black, KingSide) -> Ok("k")
        #(Black, QueenSide) -> Ok("q")
      }
    })
    |> fn(rights) {
      case rights {
        [] -> "-"
        _ -> list.fold(rights, "", fn(str, val) { str <> val })
      }
    }
  let active_color_string = case game.2 {
    Black -> "b"
    White -> "w"
  }

  let en_passant_target_string = case game.4 {
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
  game.0 |> dict.get(square)
}

pub fn piece_exists_at(
  game: Game,
  piece: piece.Piece,
  square: square.Square,
) -> Bool {
  let bit =
    int.bitwise_shift_left(1, square.rank(square) * 8 + square.file(square))
  case piece {
    piece.Piece(White, piece.Pawn) ->
      int.bitwise_or({ game.1 }.white_pawns, bit)
    piece.Piece(White, piece.Knight) ->
      int.bitwise_or({ game.1 }.white_knights, bit)
    piece.Piece(White, piece.Bishop) ->
      int.bitwise_or({ game.1 }.white_bishops, bit)
    piece.Piece(White, piece.Rook) ->
      int.bitwise_or({ game.1 }.white_rooks, bit)
    piece.Piece(White, piece.Queen) ->
      int.bitwise_or({ game.1 }.white_queens, bit)
    piece.Piece(White, piece.King) -> int.bitwise_or({ game.1 }.white_king, bit)

    piece.Piece(Black, piece.Pawn) ->
      int.bitwise_or({ game.1 }.black_pawns, bit)
    piece.Piece(Black, piece.Knight) ->
      int.bitwise_or({ game.1 }.black_knights, bit)
    piece.Piece(Black, piece.Bishop) ->
      int.bitwise_or({ game.1 }.black_bishops, bit)
    piece.Piece(Black, piece.Rook) ->
      int.bitwise_or({ game.1 }.black_rooks, bit)
    piece.Piece(Black, piece.Queen) ->
      int.bitwise_or({ game.1 }.black_queens, bit)
    piece.Piece(Black, piece.King) -> int.bitwise_or({ game.1 }.black_king, bit)
  }
  != 0
}

pub fn empty_at(game: Game, square: square.Square) -> Bool {
  let square = bitboard.from_square(square)
  0 == int.bitwise_and(square, bitboard.get_bitboard_all(game.1))
}

pub fn find_piece(game: Game, piece: piece.Piece) -> List(square.Square) {
  dict.filter(game.0, fn(_, p) { p == piece })
  |> dict.keys()
}

pub fn is_check(game: Game, player: player.Player) -> Bool {
  let assert Ok(#(king_position, _king_piece)) =
    game.0
    |> dict.to_list
    |> list.find(fn(x) { x.1 == piece.Piece(player, piece.King) })
  square.is_attacked_at(game.0, king_position, player.opponent(player))
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
  !is_check(game, game.2) && valid_moves(game) |> list.is_empty
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
            case dict.get(game.0, square) {
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
  game.0 |> dict.to_list
}

pub fn has_castled(game: Game, player: player.Player) {
  !can_castle(game, player)
}

pub fn can_castle(game: Game, player: player.Player) {
  case player {
    White -> { game.3 }.white_kingside || { game.3 }.white_queenside
    Black -> { game.3 }.black_kingside || { game.3 }.black_queenside
  }
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
  let us = game.2
  let them = player.opponent(us)
  let from = move.get_from(move)
  let to = move.get_to(move)
  let assert Ok(us_piece) = dict.get(game.0, from)
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
      dict.get(game.0, to)
      |> result.map(fn(x) { x.player == them })
      |> result.unwrap(False)

    // Calculate pawn moves
    let pawn_san = {
      use <- bool.guard(us_piece.symbol != piece.Pawn, Error(Nil))
      let is_capture = is_capture || Some(#(them, to)) == game.4
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
          && { dict.get(game.0, move.get_from(other_move)) == Ok(us_piece) }
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
        int.bitwise_exclusive_or(hash, zobrist.piece_hash(square, piece)),
      )
    }
    BoardInsertion(square, piece) -> {
      let #(board, bitboard, hash) = bbh
      #(
        dict.insert(board, square, piece),
        // mask it in
        bitboard.or(bitboard, piece, bitboard.from_square(square)),
        // XOR squares in
        int.bitwise_exclusive_or(hash, zobrist.piece_hash(square, piece)),
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
  let #(
    board,
    bitboard,
    us,
    castling_availability,
    _,
    halfmove_clock,
    fullmove_number,
    hash,
    prev_en_passant_hash,
  ) = game
  let prev_castling_availability = castling_availability
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
  let castling_availability = {
    let we_castled = move_context.castling |> option.is_some
    let we_moved_king = piece == piece.Piece(us, piece.King)

    let castling_availability = case we_castled || we_moved_king {
      True ->
        case us {
          White ->
            CastlingAvailability(
              ..castling_availability,
              white_kingside: False,
              white_queenside: False,
            )
          Black ->
            CastlingAvailability(
              ..castling_availability,
              black_kingside: False,
              black_queenside: False,
            )
        }
      False -> castling_availability
    }
    // Did we move a rook? Then disable it
    let castling_availability = case us, piece, square.to_ox88(from) {
      White, piece.Piece(_, piece.Rook), 0x07 ->
        CastlingAvailability(..castling_availability, white_kingside: False)
      White, piece.Piece(_, piece.Rook), 0x00 ->
        CastlingAvailability(..castling_availability, white_queenside: False)
      Black, piece.Piece(_, piece.Rook), 0x77 ->
        CastlingAvailability(..castling_availability, black_kingside: False)
      Black, piece.Piece(_, piece.Rook), 0x70 ->
        CastlingAvailability(..castling_availability, black_queenside: False)
      _, _, _ -> castling_availability
    }
    // Did we kill their rook? Then disable it
    let castling_availability = case
      them,
      move_context.capture,
      square.to_ox88(to)
    {
      White, Some(#(_, piece.Piece(_, piece.Rook))), 0x07 ->
        CastlingAvailability(..castling_availability, white_kingside: False)
      White, Some(#(_, piece.Piece(_, piece.Rook))), 0x00 ->
        CastlingAvailability(..castling_availability, white_queenside: False)
      Black, Some(#(_, piece.Piece(_, piece.Rook))), 0x77 ->
        CastlingAvailability(..castling_availability, black_kingside: False)
      Black, Some(#(_, piece.Piece(_, piece.Rook))), 0x70 ->
        CastlingAvailability(..castling_availability, black_queenside: False)
      _, _, _ -> castling_availability
    }

    castling_availability
  }

  let fullmove_number = case us {
    Black -> fullmove_number + 1
    White -> fullmove_number
  }
  let halfmove_clock = case move_context.piece.symbol, move_context.capture {
    piece.Pawn, _ | _, Some(_) -> 0
    _, _ -> halfmove_clock + 1
  }

  let en_passant_hash = ep_hash(them, bitboard, en_passant_target_square)
  // Turn hash
  let hash =
    hash
    |> int.bitwise_exclusive_or(zobrist.hashes.780)
    // En passant hash
    |> int.bitwise_exclusive_or(prev_en_passant_hash)
    |> int.bitwise_exclusive_or(en_passant_hash)

  // Castle hash
  let hash = case prev_castling_availability, castling_availability {
    CastlingAvailability(True, _, _, _), CastlingAvailability(False, _, _, _) ->
      int.bitwise_exclusive_or(hash, zobrist.hashes.768)

    _, _ -> hash
  }
  let hash = case prev_castling_availability, castling_availability {
    CastlingAvailability(_, True, _, _), CastlingAvailability(_, False, _, _) ->
      int.bitwise_exclusive_or(hash, zobrist.hashes.769)

    _, _ -> hash
  }
  let hash = case prev_castling_availability, castling_availability {
    CastlingAvailability(_, _, True, _), CastlingAvailability(_, _, False, _) ->
      int.bitwise_exclusive_or(hash, zobrist.hashes.770)

    _, _ -> hash
  }
  let hash = case prev_castling_availability, castling_availability {
    CastlingAvailability(_, _, _, True), CastlingAvailability(_, _, _, False) ->
      int.bitwise_exclusive_or(hash, zobrist.hashes.771)

    _, _ -> hash
  }

  #(
    board,
    bitboard,
    them,
    castling_availability,
    en_passant_target_square,
    halfmove_clock,
    fullmove_number,
    hash,
    en_passant_hash,
  )
}

pub fn find_player_king(game: Game, player: player.Player) {
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

fn generate_castle_move(game: Game, castle_player, castle) {
  let us = game.2
  let them = player.opponent(us)

  use <- bool.guard(castle_player != us, Error(Nil))
  let occupancy_blocked =
    castle.occupancy_squares(us, castle)
    |> list.any(fn(square) { dict.get(game.0, square) |> result.is_ok })
  use <- bool.guard(occupancy_blocked, Error(Nil))
  let attacked_somewhere =
    castle.unattacked_squares(us, castle)
    |> list.any(square.is_attacked_at(game.0, _, them))
  use <- bool.guard(attacked_somewhere, Error(Nil))

  let rank = square.player_rank(us)
  let to_file = case castle {
    KingSide -> 6
    QueenSide -> 2
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
}

/// generate valid moves
pub fn valid_moves(game: Game) -> List(move.Move(move.ValidInContext)) {
  let us = game.2
  let them = player.opponent(us)

  let pieces = game.0 |> dict.to_list
  let pieces_yielder = pieces |> yielder.from_list

  let king_piece = piece.Piece(us, piece.King)
  // let king_position = find_player_king(game, us)
  let assert [king_position] = find_piece(game, king_piece)

  // find attacks and pins to the king
  let #(king_attackers, king_blockers) = {
    let #(attackers, pins) =
      square.attacks_and_pins_to(game.0, pieces_yielder, king_position, them)
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
      game.0
      |> dict.delete(king_position)
    square.piece_attack_offsets(king_piece)
    |> list.filter_map(fn(offset) {
      use to <- result.try(square.add(king_position, offset))
      let hit_piece = dict.get(game.0, to)
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
      result.try(list.first(king_attackers), dict.get(game.0, _))
    {
      Ok(x) if x.symbol == piece.Knight || x.symbol == piece.Pawn -> {
        let assert [attacker_square] = king_attackers
        let assert Ok(attacker_piece) = dict.get(game.0, attacker_square)
        square.get_squares_attacking_at(
          game.0,
          pieces_yielder,
          attacker_square,
          us,
        )
        |> list.filter_map(fn(defender_square) {
          let assert Ok(piece) = dict.get(game.0, defender_square)
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
            case dict.get(game.0, square) {
              Ok(piece.Piece(player, _)) if player == them -> True
              _ -> False
            }
          },
          // check if square is empty
          fn(square) { dict.get(game.0, square) |> result.is_error },
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
          square.piece_attacking(game.0, from, piece, True)
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
              case dict.get(game.0, square) {
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
            square.piece_attacking(game.0, from, piece, True)
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
          dict.get(game.0, to)
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
    game.4
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
        use piece <- result.try(dict.get(game.0, from))
        use <- bool.guard(piece != piece.Piece(us, piece.Pawn), Error(Nil))
        let new_board =
          dict.delete(game.0, from)
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

    // Yes, this is actually more performant.
    let castle_moves = case us {
      White -> {
        case game.3 {
          CastlingAvailability(True, False, _, _) ->
            case generate_castle_move(game, White, KingSide) {
              Ok(m) -> [m]
              Error(_) -> []
            }
          CastlingAvailability(False, True, _, _) ->
            case generate_castle_move(game, White, QueenSide) {
              Ok(m) -> [m]
              Error(_) -> []
            }
          CastlingAvailability(True, True, _, _) ->
            case
              generate_castle_move(game, White, KingSide),
              generate_castle_move(game, White, QueenSide)
            {
              Ok(m1), Ok(m2) -> [m1, m2]
              Ok(m1), Error(_) -> [m1]
              Error(_), Ok(m2) -> [m2]
              _, _ -> []
            }
          _ -> []
        }
      }
      Black -> {
        case game.3 {
          CastlingAvailability(_, _, True, False) ->
            case generate_castle_move(game, Black, KingSide) {
              Ok(m) -> [m]
              Error(_) -> []
            }
          CastlingAvailability(_, _, False, True) ->
            case generate_castle_move(game, Black, QueenSide) {
              Ok(m) -> [m]
              Error(_) -> []
            }
          CastlingAvailability(_, _, True, True) ->
            case
              generate_castle_move(game, Black, KingSide),
              generate_castle_move(game, Black, QueenSide)
            {
              Ok(m1), Ok(m2) -> [m1, m2]
              Ok(m1), Error(_) -> [m1]
              Error(_), Ok(m2) -> [m2]
              _, _ -> []
            }
          _ -> []
        }
      }
    }
    castle_moves
  }

  list.flatten([king_moves, regular_moves, en_passant_move, castling_moves])
}

// Zobrist below

pub type Hash =
  Int

/// Expensive! This re-computes the hash. Use `hash()` instead.
///
pub fn compute_zobrist_hash(game: Game) {
  compute_zobrist_hash_impl(game.2, game.0, game.1, game.3, game.4)
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
  castling_availability: CastlingAvailability,
  en_passant_target_square: Option(#(player.Player, square.Square)),
) -> Hash {
  let piece_hash =
    dict.to_list(board)
    |> list.fold(0x0, fn(acc, x) {
      int.bitwise_exclusive_or(acc, zobrist.piece_hash(x.0, x.1))
    })

  let castle_hash = castle_hash(castling_availability)

  let en_passant_hash = ep_hash(us, bb, en_passant_target_square)

  let turn_hash = case us {
    White -> {
      let assert Ok(hash) = zobrist.get_hash(zobrist.turn_offset)
      hash
    }
    Black -> 0x0
  }

  piece_hash
  |> int.bitwise_exclusive_or(castle_hash)
  |> int.bitwise_exclusive_or(en_passant_hash)
  |> int.bitwise_exclusive_or(turn_hash)
}

pub fn castle_hash(castling_availability: CastlingAvailability) {
  let hash = 0x0
  let hash = case castling_availability.white_kingside {
    True -> int.bitwise_exclusive_or(hash, zobrist.hashes.768)
    False -> hash
  }
  let hash = case castling_availability.white_queenside {
    True -> int.bitwise_exclusive_or(hash, zobrist.hashes.769)
    False -> hash
  }
  let hash = case castling_availability.black_kingside {
    True -> int.bitwise_exclusive_or(hash, zobrist.hashes.770)
    False -> hash
  }
  let hash = case castling_availability.black_queenside {
    True -> int.bitwise_exclusive_or(hash, zobrist.hashes.771)
    False -> hash
  }
  hash
}

pub fn ep_hash(
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
      Black -> direction.Up
      White -> direction.Down
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
          Black -> bb.black_pawns
          White -> bb.white_pawns
        })
      }
      != 0

    case can_attack {
      True -> {
        let assert Ok(hash) =
          zobrist.get_hash(zobrist.en_passant_offset + square.file(square))
        hash
      }
      False -> 0x0
    }
  })
  |> option.unwrap(0x0)
}
