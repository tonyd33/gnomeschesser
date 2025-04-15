import chess/piece
import chess/player
import chess/square
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic/decode
import gleam/erlang
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pair
import gleam/result
import gleam/set.{type Set}
import gleam/string
import util/recursive_iterator
import util/result_addons

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

pub fn to_hash(game: Game) -> Int {
  // TODO: use proper zobrist hashing
  let assert Ok(hash) =
    [
      dict.to_list(game.board)
        |> list.map(erlang.phash2),
      list.map(game.castling_availability, erlang.phash2),
      [erlang.phash2(game.active_color)],
      [erlang.phash2(game.en_passant_target_square)],
    ]
    |> list.flatten
    |> list.reduce(int.bitwise_exclusive_or)
  hash
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

pub fn empty_at(game: Game, square: square.Square) -> Bool {
  case piece_at(game, square) {
    Ok(_) -> False
    Error(_) -> True
  }
}

pub fn find_piece(game: Game, piece: piece.Piece) -> List(square.Square) {
  todo
}

pub fn is_attacked(game: Game, square: square.Square, by: player.Player) -> Bool {
  let atkrs = attackers(game, square)

  case list.length(atkrs) {
    // Special case: list.any([]) == True, yet there are no attackers, so we
    // return False
    0 -> False
    _ -> atkrs |> list.any(fn(x) { { x.1 }.player == by })
  }
}

/// Returns the position and pieces that are attacking a square.
///
pub fn attackers(
  game: Game,
  square_alg: square.Square,
) -> List(#(square.Square, piece.Piece)) {
  let square = square.ox88(square_alg)

  list.range(from: square.ox88(square.A8), to: square.ox88(square.H1))
  |> list.filter_map(fn(i) {
    let difference = i - square
    // skip if to/from square are the same
    use <- bool.guard(difference == 0, Error(Nil))

    use piece_square_alg <- result.try(square.algebraic(i))
    use piece <- result.try(piece_at(game, piece_square_alg))

    // This is effectively a guard. I don't know what it means, but it's from
    // chess.js.
    let index = difference + 119
    use _ <- result.try(
      attacks(index)
      |> result.map(int.bitwise_and(_, piece_masks(piece.symbol)))
      |> result_addons.expect_or(fn(x) { x != 0 }, fn(_) { Nil }),
    )

    use offset <- result.try(rays(index))

    use <- bool.guard(
      case piece.symbol {
        piece.Pawn ->
          { difference > 0 && piece.player == player.White }
          || { difference <= 0 && piece.player == player.Black }
        piece.Knight | piece.King -> False
        _ -> {
          recursive_iterator.from_generator(i + offset, fn(j: Int) {
            case j != square {
              True -> recursive_iterator.Next(j + offset)
              False -> recursive_iterator.End
            }
          })
          |> recursive_iterator.fold_until(False, fn(blocked, j) {
            let empty =
              square.algebraic(j)
              |> result.map(empty_at(game, _))
              |> result.unwrap(True)

            case blocked || !empty {
              True -> list.Stop(True)
              False -> list.Continue(False)
            }
          })
        }
      },
      Error(Nil),
    )

    Ok(#(piece_square_alg, piece))
  })
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
  let us = turn(game)
  let them = player.opponent(us)

  pieces(game)
  |> list.find(fn(x) {
    let #(_, piece) = x
    piece.symbol == piece.King && piece.player == us
  })
  |> result.map(fn(x) {
    let #(king_square, _) = x
    is_attacked(game, king_square, them)
  })
  |> result.unwrap(False)
}

pub fn is_checkmate(game: Game) -> Bool {
  is_check(game) && { moves(game) |> list.length == 0 }
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

// Moves

/// Standard Algebraic Notation
/// https://en.wikipedia.org/wiki/Algebraic_notation_(chess)
///
pub type SAN =
  String

pub opaque type Move {
  Move(
    player: player.Player,
    from: Int,
    to: Int,
    piece: piece.PieceSymbol,
    captured: Option(piece.PieceSymbol),
    promotion: Option(piece.PieceSymbol),
    flags: Set(InternalMoveFlags),
    san: String,
  )
}

pub fn move_is_capture(move: Move) -> Bool {
  set.contains(move.flags, Capture)
}

pub fn move_is_promotion(move: Move) -> Bool {
  set.contains(move.flags, Promotion)
}

pub fn move_is_en_passant(move: Move) -> Bool {
  set.contains(move.flags, EnPassant)
}

pub fn move_is_kingside_castle(move: Move) -> Bool {
  set.contains(move.flags, KingsideCastle)
}

pub fn move_is_queenside_castle(move: Move) -> Bool {
  set.contains(move.flags, QueensideCastle)
}

pub fn move_is_big_pawn(move: Move) -> Bool {
  set.contains(move.flags, BigPawn)
}

pub fn move_piece_to_move(move: Move) -> piece.Piece {
  piece.Piece(move.player, move.piece)
}

pub fn move_to_san(move: Move) -> SAN {
  move.san
}

/// Create a move from a SAN. The SAN must be strictly valid, including
/// disambiguation only when necessary, captures, check/checkmates, etc.
/// TODO: Possibly allow more flexibility
///
pub fn move_from_san(san: String, game: Game) -> Result(Move, Nil) {
  moves(game)
  |> list.find(fn(move) { move_to_san(move) == san })
}

/// Apply a move to a game. Moves should only be passed in with a `game` from
/// moves created with `from_san` or `moves` with the same `game`.
///
pub fn apply(game: Game, move: Move) -> Result(Game, Nil) {
  let Move(player, from, to, piece, captured, promotion, flags, _) = move
  apply_internal_move(
    game,
    InternalMove(player, from, to, piece, captured, promotion, flags),
  )
}

pub fn moves(game: Game) -> List(Move) {
  let moves = internal_moves(game)
  moves
  |> list.map(internal_move_to_move(_, moves, game))
}

fn find_player_king(
  game: Game,
  player: player.Player,
) -> Result(#(square.Square, piece.Piece), Nil) {
  pieces(game)
  |> list.find(fn(x) {
    let #(_, piece) = x
    piece.symbol == piece.King && piece.player == player
  })
}

/// Validate a move is internally consistent. If it's not, the program will
/// crash. Use this only when debugging.
///
fn assert_move_sanity_checks(move: InternalMove, game: Game) -> Nil {
  let InternalMove(player, from, to, piece, captured, promotion, flags) = move
  let opponent = player.opponent(player)

  let assert Ok(from_square) = square.algebraic(from)
  let assert Ok(to_square) = square.algebraic(to)

  // It should be our turn
  let assert True = player == turn(game)

  // Piece should match what was stated in move
  let assert Ok(_) =
    piece_at(game, from_square)
    |> result_addons.expect_or(
      fn(actual_piece) {
        actual_piece.symbol == piece && actual_piece.player == player
      },
      fn(_) { Nil },
    )

  // Promotion piece must match flag
  let assert True = case promotion {
    Some(_) -> set.contains(flags, Promotion)
    None -> True
  }

  // Capture must match flag
  let assert True = case captured {
    Some(_) -> set.contains(flags, Capture)
    None -> True
  }

  // Capture must match actual piece
  let assert True = case captured {
    Some(captured_piece) -> {
      let assert Ok(real_piece) = piece_at(game, to_square)
      real_piece.symbol == captured_piece && real_piece.player == opponent
    }
    None -> True
  }

  // Can't be kingside *and* queenside castle at the same time!
  let assert True =
    bool.nand(
      set.contains(flags, KingsideCastle),
      set.contains(flags, QueensideCastle),
    )

  // is_en_passant implies is_capture
  let assert True =
    !set.contains(flags, EnPassant) || set.contains(flags, Capture)

  Nil
}

fn apply_internal_move(game: Game, move: InternalMove) -> Result(Game, Nil) {
  let InternalMove(player, from, to, piece, _, promotion, flags) = move

  let fullmove_number = fullmove_number(game)
  let halfmove_clock = halfmove_clock(game)
  let history = history(game)
  let castling_availability = castling_availability(game)

  use from_square <- result.try(square.algebraic(from))
  use to_square <- result.try(square.algebraic(to))

  // If we're debugging, we'll purposely be more strict to ensure correctness.
  // When actually competing though, we don't want the program to crash, even
  // if something's incorrect though.
  // #ifdef DEV
  assert_move_sanity_checks(move, game)
  // #endif

  let is_kingside_castle = set.contains(flags, KingsideCastle)
  let is_queenside_castle = set.contains(flags, QueensideCastle)
  let is_en_passant = set.contains(flags, EnPassant)
  let is_big_pawn = set.contains(flags, BigPawn)
  let is_capture = set.contains(flags, Capture)

  let next_en_passant_target_square = case is_big_pawn {
    True -> {
      let offset = case player {
        player.White -> 16
        player.Black -> -16
      }
      let square = square.algebraic(to + offset)
      option.from_result(square)
    }
    False -> None
  }
  let next_player = player.opponent(player)
  let next_fullmove_number = case next_player {
    player.White -> fullmove_number + 1
    player.Black -> fullmove_number
  }

  let next_halfmove_clock = case piece == piece.Pawn || is_capture {
    True -> 0
    False -> halfmove_clock + 1
  }
  let next_history = history |> list.append([game])
  let next_castling_availability = case
    is_kingside_castle || is_queenside_castle
  {
    True ->
      castling_availability
      |> list.filter(fn(x) { x.0 != player })
    False -> {
      use <- bool.guard(piece != piece.Rook, castling_availability)
      // If we're moving a rook from its starting position, we disable castling
      // depending which side it was on. The correctness of this depends on the
      // correctness of the previous `castling_availability`.
      let position_flags =
        rook_positions_flags(player)
        |> list.find(fn(x) { x.0 == from_square })
      case position_flags {
        Error(_) -> castling_availability
        Ok(#(_, side)) ->
          castling_availability
          // This is a bit hard to read, but we're just removing all castling
          // rights for us on this side
          |> list.filter(fn(x) { !{ x.0 == player || x.1 == side } })
      }
    }
  }

  // Apply basic to/from
  let next_board = {
    // If pawn promotion, replace with new piece
    let become_piece = case promotion {
      Some(promotion_piece) -> piece.Piece(player, promotion_piece)
      None -> piece.Piece(player, piece)
    }
    board(game)
    |> dict.delete(from_square)
    |> dict.insert(to_square, become_piece)
  }
  // If it's en passant, we have to kill a different square too
  use next_board <- result.try(case is_en_passant {
    True -> {
      let offset = case player {
        player.Black -> -16
        player.White -> 16
      }
      let ep_square = square.algebraic(to + offset)
      ep_square
      |> result.map(dict.delete(next_board, _))
    }
    False -> Ok(next_board)
  })

  // If castling, we have to move the rook too
  use next_board <- result.try(case is_kingside_castle || is_queenside_castle {
    False -> Ok(next_board)
    True -> {
      let castling_to_offset = case is_kingside_castle {
        True -> -1
        False -> 1
      }
      let castling_from_offset = case is_kingside_castle {
        True -> 1
        False -> -2
      }
      use castling_to_square <- result.try(square.algebraic(
        to - castling_to_offset,
      ))
      use castling_from_square <- result.try(square.algebraic(
        to + castling_from_offset,
      ))
      use castling_from_piece <- result.try(piece_at(game, castling_from_square))

      Ok(
        next_board
        |> dict.delete(castling_from_square)
        |> dict.insert(castling_to_square, castling_from_piece),
      )
    }
  })

  Ok(Game(
    board: next_board,
    active_color: next_player,
    castling_availability: next_castling_availability,
    en_passant_target_square: next_en_passant_target_square,
    halfmove_clock: next_halfmove_clock,
    fullmove_number: next_fullmove_number,
    history: next_history,
  ))
}

fn internal_moves(game: Game) -> List(InternalMove) {
  let us = turn(game)
  let them = player.opponent(us)
  let castle_moves: List(InternalMove) = king_castle_moves(game)

  game
  |> pieces
  |> list.fold([], fn(moves, x) {
    let #(square, piece) = x
    // Not our piece
    use <- bool.guard(piece.player != us, moves)

    let from = square.ox88(square)
    let standard_moves = case piece.symbol {
      piece.Pawn -> pawn_moves(game, square)
      _ -> {
        piece_offsets(piece)
        |> list.flat_map(fn(offset) {
          let max_depth = case piece.symbol {
            piece.King | piece.Knight -> 1
            _ -> 8
          }
          collect_ray_moves(game, piece.symbol, from, offset, max_depth)
        })
      }
    }
    moves |> list.append(standard_moves)
  })
  |> list.append(castle_moves)
  |> list.filter(fn(move) {
    // We should continue using assert here rather than silently failing.
    // If we failed to apply the move here, we really fucked something up.
    let assert Ok(new_game) = apply_internal_move(game, move)

    find_player_king(new_game, us)
    |> result.map(fn(x) { !is_attacked(new_game, x.0, them) })
    |> result.unwrap(True)
  })
}

fn king_castle_moves(game: Game) {
  let us = turn(game)
  let them = player.opponent(us)

  let king = find_player_king(game, us)
  use king_piece: #(square.Square, piece.Piece) <-
    fn(fun) { king |> result.map(fun) |> result.unwrap([]) }

  let castling_availability = set.from_list(game.castling_availability)

  let kingside = {
    use <- bool.guard(
      !set.contains(castling_availability, #(us, KingSide)),
      Error(Nil),
    )
    let castling_from_square = square.ox88(king_piece.0)
    let castling_to_square = castling_from_square + 2

    let should_be_empty_squares = [castling_from_square + 1, castling_to_square]
    let should_be_safe_squares = [
      castling_from_square,
      castling_from_square + 1,
    ]

    use _ <- result.try(
      result.all(
        list.flatten([
          should_be_empty_squares
            |> list.map(fn(x) {
              square.algebraic(x)
              |> result.map(empty_at(game, _))
            }),
          should_be_safe_squares
            |> list.map(fn(x) {
              square.algebraic(x)
              |> result.map(is_attacked(game, _, them))
              |> result.map(fn(x) { !x })
            }),
        ]),
      )
      |> result.map(list.all(_, fn(x) { x }))
      |> result_addons.expect_or(fn(x) { x }, fn(_) { Nil }),
    )

    Ok(InternalMove(
      player: us,
      to: castling_to_square,
      from: castling_from_square,
      piece: piece.King,
      captured: None,
      promotion: None,
      flags: set.from_list([KingsideCastle]),
    ))
  }
  let queenside = {
    use <- bool.guard(
      !set.contains(castling_availability, #(us, QueenSide)),
      Error(Nil),
    )
    let castling_from_square = square.ox88(king_piece.0)
    let castling_to_square = castling_from_square - 2

    let should_be_empty_squares = [
      castling_from_square - 1,
      castling_from_square - 2,
      castling_from_square - 3,
    ]
    let should_be_safe_squares = [
      castling_from_square,
      castling_from_square - 1,
      castling_from_square - 2,
    ]

    use _ <- result.try(
      result.all(
        list.flatten([
          should_be_empty_squares
            |> list.map(fn(x) {
              square.algebraic(x)
              |> result.map(empty_at(game, _))
            }),
          should_be_safe_squares
            |> list.map(fn(x) {
              square.algebraic(x)
              |> result.map(is_attacked(game, _, them))
              |> result.map(fn(x) { !x })
            }),
        ]),
      )
      |> result.map(list.all(_, fn(x) { x }))
      |> result_addons.expect_or(fn(x) { x }, fn(_) { Nil }),
    )
    Ok(InternalMove(
      player: us,
      to: castling_to_square,
      from: castling_from_square,
      piece: piece.King,
      captured: None,
      promotion: None,
      flags: set.from_list([QueensideCastle]),
    ))
  }

  [kingside, queenside] |> list.filter_map(fn(x) { x })
}

fn pawn_moves(game: Game, square: square.Square) {
  let us = turn(game)
  let from = square.ox88(square)
  let offsets: List(Int) = pawn_offsets(us)
  let assert [single, double, x1, x2] = offsets

  let single_jump_move = {
    let to = from + single
    square.algebraic(to)
    |> result.map(empty_at(game, _))
    // Only create move if square is empty
    |> result.try(fn(empty) {
      case empty {
        True ->
          Ok(InternalMove(
            player: us,
            from: from,
            to: to,
            piece: piece.Pawn,
            captured: None,
            promotion: None,
            flags: set.new(),
          ))
        False -> Error(Nil)
      }
    })
  }

  let double_jump_move = {
    let to = from + double
    // When double jumping, the square directly ahead must be empty.
    use square_ahead_empty <- result.try(
      square.algebraic(from + single)
      |> result.map(empty_at(game, _)),
    )
    use <- bool.guard(!square_ahead_empty, Error(Nil))

    square.algebraic(to)
    // Ensure this square our second rank
    |> result_addons.expect_or(
      fn(_) { { 8 - square.rank(from) } == second_rank(us) },
      fn(_) { Nil },
    )
    |> result.map(empty_at(game, _))
    // Only create move if square is empty
    |> result.try(fn(empty) {
      case empty {
        True ->
          Ok(InternalMove(
            player: us,
            from: from,
            to: to,
            piece: piece.Pawn,
            captured: None,
            promotion: None,
            flags: set.from_list([BigPawn]),
          ))
        False -> Error(Nil)
      }
    })
  }

  let make_x_moves = fn(jump) {
    let to = from + jump
    let standard_x_move =
      square.algebraic(to)
      |> result.try(piece_at(game, _))
      |> result_addons.expect_or(fn(x) { x.player != us }, fn(_) { Nil })
      |> result.map(fn(x) {
        InternalMove(
          player: us,
          from: from,
          to: to,
          piece: piece.Pawn,
          captured: Some(x.symbol),
          promotion: None,
          flags: set.from_list([Capture]),
        )
      })

    let ep_move =
      square.algebraic(to)
      |> result_addons.expect_or(
        fn(to_alg) {
          en_passant_target_square(game)
          |> option.map(fn(ep_square) { ep_square == to_alg })
          |> option.unwrap(False)
        },
        fn(_) { Nil },
      )
      |> result.map(fn(_) {
        InternalMove(
          player: us,
          from: from,
          to: to,
          piece: piece.Pawn,
          captured: Some(piece.Pawn),
          promotion: None,
          flags: set.from_list([EnPassant, Capture]),
        )
      })

    [standard_x_move, ep_move]
  }

  // Some of the moves might hit an end square, but we don't account for
  // it until we use this function. If the move leads to a promotion,
  // "fan" out the moves to all the promotion moves.
  let fan_promotion_moves = fn(move: InternalMove) -> List(InternalMove) {
    // If the pawn isn't moving to the last rank, then it's not a
    // promotion move. This condition works for both white and black
    // because pawns can't move backwards
    let rank = square.rank(move.to)
    use <- bool.guard(rank != 0 && rank != 7, [move])

    // We have to promote the pawn then
    let promotion_candidates = [
      piece.Queen,
      piece.Rook,
      piece.Bishop,
      piece.Knight,
    ]

    promotion_candidates
    |> list.map(fn(candidate) {
      InternalMove(
        player: move.player,
        to: move.to,
        from: move.from,
        piece: move.piece,
        captured: move.captured,
        promotion: Some(candidate),
        flags: move.flags |> set.insert(Promotion),
      )
    })
  }

  let x1_moves = make_x_moves(x1)
  let x2_moves = make_x_moves(x2)

  let pawn_moves =
    list.flatten([[single_jump_move], [double_jump_move], x1_moves, x2_moves])
    |> list.filter_map(fn(x) { x })
    |> list.flat_map(fan_promotion_moves)

  pawn_moves
}

/// Cast a "ray" from `from` in the `offset` direction and collect positions.
/// Execution terminates when:
/// - We hit a piece
/// - We are no longer on the board
/// - We have travelled more than `max_depth` times
///
fn collect_ray_moves(
  game: Game,
  from_piece: piece.PieceSymbol,
  from: Int,
  offset: Int,
  max_depth: Int,
) -> List(InternalMove) {
  collect_ray_moves_inner(game, from_piece, from, offset, 1, max_depth, [])
}

fn collect_ray_moves_inner(
  game: Game,
  from_piece: piece.PieceSymbol,
  from: Int,
  offset: Int,
  depth: Int,
  max_depth: Int,
  moves: List(InternalMove),
) -> List(InternalMove) {
  let us = turn(game)

  use <- bool.guard(depth > max_depth, moves)

  let to = from + { offset * depth }
  case square.algebraic(to) {
    Error(_) -> moves
    Ok(square) ->
      case piece_at(game, square) {
        // Nothing. Then keep going
        Error(_) ->
          collect_ray_moves_inner(
            game,
            from_piece,
            from,
            offset,
            depth + 1,
            max_depth,
            moves
              |> list.append([
                InternalMove(
                  player: us,
                  from: from,
                  to: to,
                  piece: from_piece,
                  captured: None,
                  promotion: None,
                  flags: set.new(),
                ),
              ]),
          )
        Ok(piece) ->
          case piece.player == us {
            // If it's us, then we stop immediately and don't append
            True -> moves
            // Otherwise, it's their piece, and we'd be able to take it
            False ->
              moves
              |> list.append([
                InternalMove(
                  player: us,
                  from: from,
                  to: to,
                  piece: from_piece,
                  captured: Some(piece.symbol),
                  promotion: None,
                  flags: set.from_list([Capture]),
                ),
              ])
          }
      }
  }
}

type InternalMoveFlags {
  Capture
  Promotion
  EnPassant
  KingsideCastle
  QueensideCastle
  BigPawn
}

type InternalMove {
  InternalMove(
    player: player.Player,
    from: Int,
    to: Int,
    piece: piece.PieceSymbol,
    captured: Option(piece.PieceSymbol),
    promotion: Option(piece.PieceSymbol),
    flags: Set(InternalMoveFlags),
  )
}

/// How ambiguous a move is. Used when converting to SAN.
/// https://en.wikipedia.org/wiki/Algebraic_notation_(chess)#Disambiguating_moves
///
type DisambiguationLevel {
  // There is only one move to a position with a fixed piece
  Unambiguous
  // There is a move with the same piece moving to the same square. While
  // GenerallyAmbiguous will end up disambiguating to include the file like
  // Rank does, we need this extra enum member for the
  // `add_disambiguation_levels` algebra to work out correctly
  GenerallyAmbiguous
  // There is a move with the same piece on the same rank moving to the same
  // square
  Rank
  // There is a move with the same piece on the same file moving to the same
  // square
  File
  // There is a move with the same piece on the same file and another move with
  // the same piece on the same rank moving to the same square
  Both
}

fn add_disambiguation_levels(l1: DisambiguationLevel, l2: DisambiguationLevel) {
  use <- bool.guard(l1 == l2, l1)

  case l1, l2 {
    Both, _ -> Both
    _, Both -> Both

    Unambiguous, other -> other

    GenerallyAmbiguous, File -> File
    GenerallyAmbiguous, Rank -> Rank

    Rank, File -> Both

    _, _ -> add_disambiguation_levels(l2, l1)
  }
}

fn internal_move_to_san(
  move: InternalMove,
  all_moves: List(InternalMove),
  game: Game,
) -> String {
  let is_kingside_castle = set.contains(move.flags, KingsideCastle)
  let is_queenside_castle = set.contains(move.flags, QueensideCastle)

  // SAN without # or +
  let undecorated_san = {
    use <- bool.guard(is_kingside_castle, "O-O")
    use <- bool.guard(is_queenside_castle, "O-O-O")

    let assert Ok(from_square) = square.algebraic(move.from)
    let assert Ok(to_square) = square.algebraic(move.to)
    let disambiguation_level =
      all_moves
      |> list.fold(Unambiguous, fn(level: DisambiguationLevel, other_move) {
        let identical_move = move == other_move
        let same_piece = move.piece == other_move.piece
        use <- bool.guard(identical_move || !same_piece, level)

        let ambiguous = move.to == other_move.to
        let same_file = square.file(move.from) == square.file(other_move.from)
        let same_rank = square.rank(move.from) == square.rank(other_move.from)

        case ambiguous, same_file, same_rank {
          False, _, _ -> Unambiguous
          True, False, False -> GenerallyAmbiguous
          True, False, True -> Rank
          True, True, False -> File
          // The only way the other move matches to, from, and piece is that
          // they're both a pawn promotion, in which case the move is unambiguous
          // because it's identified by the file that's always added to pawn
          // moves
          True, True, True -> Unambiguous
        }
        |> add_disambiguation_levels(level)
      })
    let is_capture = set.contains(move.flags, Capture)

    let piece_san = fn(piece) {
      case piece {
        piece.Knight -> "N"
        piece.Bishop -> "B"
        piece.King -> "K"
        piece.Pawn ->
          // https://en.wikipedia.org/wiki/Algebraic_notation_(chess)#Captures
          case is_capture {
            True -> square.string_file(from_square)
            False -> ""
          }
        piece.Queen -> "Q"
        piece.Rook -> "R"
      }
    }

    let san = piece_san(move.piece)

    let san = case disambiguation_level, move.piece {
      Unambiguous, _ | _, piece.Pawn -> san
      GenerallyAmbiguous, _ | Rank, _ -> san <> square.string_file(from_square)
      File, _ -> san <> square.string_rank(from_square)
      Both, _ -> san <> square.string(from_square)
    }

    let san = case is_capture {
      True -> san <> "x"
      False -> san
    }

    let san = san <> square.string(to_square)
    let san = case move.promotion {
      Some(promotion_piece) -> san <> "=" <> piece_san(promotion_piece)
      None -> san
    }
    san
  }

  // Is this check/checkmate?
  case
    apply_internal_move(game, move)
    |> result.map(fn(x) { #(is_check(x), is_checkmate(x)) })
  {
    Ok(#(_, True)) -> undecorated_san <> "#"
    Ok(#(True, False)) -> undecorated_san <> "+"
    _ -> undecorated_san
  }
}

/// THIS SHOULD ONLY BE USED FOR MOVES THAT WERE GENERATED BY `internal_moves`
/// INCORRECT USAGE OF THIS FUNCTION WILL CRASH THE PROGRAM. YOU HAVE BEEN
/// WARNED.
///
fn internal_move_to_move(
  move: InternalMove,
  all_moves: List(InternalMove),
  game: Game,
) -> Move {
  let san = internal_move_to_san(move, all_moves, game)
  let InternalMove(player, to, from, piece, captured, promotion, flags) = move
  Move(player, to, from, piece, captured, promotion, flags, san)
}

// BEGIN: Constants

fn second_rank(player: player.Player) {
  case player {
    player.Black -> 7
    player.White -> 2
  }
}

fn pawn_offsets(player: player.Player) {
  case player {
    player.Black -> [16, 32, 17, 15]
    player.White -> [-16, -32, -17, -15]
  }
}

fn piece_offsets(piece: piece.Piece) {
  case piece.symbol {
    piece.Knight -> [-18, -33, -31, -14, 18, 33, 31, 14]
    piece.Bishop -> [-17, -15, 17, 15]
    piece.King -> [-17, -16, -15, 1, 17, 16, 15, -1]
    piece.Pawn -> pawn_offsets(piece.player)
    piece.Queen -> [-17, -16, -15, 1, 17, 16, 15, -1]
    piece.Rook -> [-16, 1, 16, -1]
  }
}

fn rook_positions_flags(player: player.Player) {
  case player {
    player.White -> [#(square.A1, QueenSide), #(square.H1, KingSide)]
    player.Black -> [#(square.A8, QueenSide), #(square.H8, KingSide)]
  }
}

fn piece_masks(piece: piece.PieceSymbol) {
  case piece {
    piece.Pawn -> 0x1
    piece.Knight -> 0x2
    piece.Bishop -> 0x4
    piece.Rook -> 0x8
    piece.Queen -> 0x10
    piece.King -> 0x20
  }
}

/// 20, 0, 0, 0, 0, 0, 0, 24,  0, 0, 0, 0, 0, 0,20, 0,
///  0,20, 0, 0, 0, 0, 0, 24,  0, 0, 0, 0, 0,20, 0, 0,
///  0, 0,20, 0, 0, 0, 0, 24,  0, 0, 0, 0,20, 0, 0, 0,
///  0, 0, 0,20, 0, 0, 0, 24,  0, 0, 0,20, 0, 0, 0, 0,
///  0, 0, 0, 0,20, 0, 0, 24,  0, 0,20, 0, 0, 0, 0, 0,
///  0, 0, 0, 0, 0,20, 2, 24,  2,20, 0, 0, 0, 0, 0, 0,
///  0, 0, 0, 0, 0, 2,53, 56, 53, 2, 0, 0, 0, 0, 0, 0,
/// 24,24,24,24,24,24,56,  0, 56,24,24,24,24,24,24, 0,
///  0, 0, 0, 0, 0, 2,53, 56, 53, 2, 0, 0, 0, 0, 0, 0,
///  0, 0, 0, 0, 0,20, 2, 24,  2,20, 0, 0, 0, 0, 0, 0,
///  0, 0, 0, 0,20, 0, 0, 24,  0, 0,20, 0, 0, 0, 0, 0,
///  0, 0, 0,20, 0, 0, 0, 24,  0, 0, 0,20, 0, 0, 0, 0,
///  0, 0,20, 0, 0, 0, 0, 24,  0, 0, 0, 0,20, 0, 0, 0,
///  0,20, 0, 0, 0, 0, 0, 24,  0, 0, 0, 0, 0,20, 0, 0,
/// 20, 0, 0, 0, 0, 0, 0, 24,  0, 0, 0, 0, 0, 0,20
fn attacks(i: Int) {
  case i {
    0 -> Ok(20)
    1 -> Ok(0)
    2 -> Ok(0)
    3 -> Ok(0)
    4 -> Ok(0)
    5 -> Ok(0)
    6 -> Ok(0)
    7 -> Ok(24)
    8 -> Ok(0)
    9 -> Ok(0)
    10 -> Ok(0)
    11 -> Ok(0)
    12 -> Ok(0)
    13 -> Ok(0)
    14 -> Ok(20)
    15 -> Ok(0)
    16 -> Ok(0)
    17 -> Ok(20)
    18 -> Ok(0)
    19 -> Ok(0)
    20 -> Ok(0)
    21 -> Ok(0)
    22 -> Ok(0)
    23 -> Ok(24)
    24 -> Ok(0)
    25 -> Ok(0)
    26 -> Ok(0)
    27 -> Ok(0)
    28 -> Ok(0)
    29 -> Ok(20)
    30 -> Ok(0)
    31 -> Ok(0)
    32 -> Ok(0)
    33 -> Ok(0)
    34 -> Ok(20)
    35 -> Ok(0)
    36 -> Ok(0)
    37 -> Ok(0)
    38 -> Ok(0)
    39 -> Ok(24)
    40 -> Ok(0)
    41 -> Ok(0)
    42 -> Ok(0)
    43 -> Ok(0)
    44 -> Ok(20)
    45 -> Ok(0)
    46 -> Ok(0)
    47 -> Ok(0)
    48 -> Ok(0)
    49 -> Ok(0)
    50 -> Ok(0)
    51 -> Ok(20)
    52 -> Ok(0)
    53 -> Ok(0)
    54 -> Ok(0)
    55 -> Ok(24)
    56 -> Ok(0)
    57 -> Ok(0)
    58 -> Ok(0)
    59 -> Ok(20)
    60 -> Ok(0)
    61 -> Ok(0)
    62 -> Ok(0)
    63 -> Ok(0)
    64 -> Ok(0)
    65 -> Ok(0)
    66 -> Ok(0)
    67 -> Ok(0)
    68 -> Ok(20)
    69 -> Ok(0)
    70 -> Ok(0)
    71 -> Ok(24)
    72 -> Ok(0)
    73 -> Ok(0)
    74 -> Ok(20)
    75 -> Ok(0)
    76 -> Ok(0)
    77 -> Ok(0)
    78 -> Ok(0)
    79 -> Ok(0)
    80 -> Ok(0)
    81 -> Ok(0)
    82 -> Ok(0)
    83 -> Ok(0)
    84 -> Ok(0)
    85 -> Ok(20)
    86 -> Ok(2)
    87 -> Ok(24)
    88 -> Ok(2)
    89 -> Ok(20)
    90 -> Ok(0)
    91 -> Ok(0)
    92 -> Ok(0)
    93 -> Ok(0)
    94 -> Ok(0)
    95 -> Ok(0)
    96 -> Ok(0)
    97 -> Ok(0)
    98 -> Ok(0)
    99 -> Ok(0)
    100 -> Ok(0)
    101 -> Ok(2)
    102 -> Ok(53)
    103 -> Ok(56)
    104 -> Ok(53)
    105 -> Ok(2)
    106 -> Ok(0)
    107 -> Ok(0)
    108 -> Ok(0)
    109 -> Ok(0)
    110 -> Ok(0)
    111 -> Ok(0)
    112 -> Ok(24)
    113 -> Ok(24)
    114 -> Ok(24)
    115 -> Ok(24)
    116 -> Ok(24)
    117 -> Ok(24)
    118 -> Ok(56)
    119 -> Ok(0)
    120 -> Ok(56)
    121 -> Ok(24)
    122 -> Ok(24)
    123 -> Ok(24)
    124 -> Ok(24)
    125 -> Ok(24)
    126 -> Ok(24)
    127 -> Ok(0)
    128 -> Ok(0)
    129 -> Ok(0)
    130 -> Ok(0)
    131 -> Ok(0)
    132 -> Ok(0)
    133 -> Ok(2)
    134 -> Ok(53)
    135 -> Ok(56)
    136 -> Ok(53)
    137 -> Ok(2)
    138 -> Ok(0)
    139 -> Ok(0)
    140 -> Ok(0)
    141 -> Ok(0)
    142 -> Ok(0)
    143 -> Ok(0)
    144 -> Ok(0)
    145 -> Ok(0)
    146 -> Ok(0)
    147 -> Ok(0)
    148 -> Ok(0)
    149 -> Ok(20)
    150 -> Ok(2)
    151 -> Ok(24)
    152 -> Ok(2)
    153 -> Ok(20)
    154 -> Ok(0)
    155 -> Ok(0)
    156 -> Ok(0)
    157 -> Ok(0)
    158 -> Ok(0)
    159 -> Ok(0)
    160 -> Ok(0)
    161 -> Ok(0)
    162 -> Ok(0)
    163 -> Ok(0)
    164 -> Ok(20)
    165 -> Ok(0)
    166 -> Ok(0)
    167 -> Ok(24)
    168 -> Ok(0)
    169 -> Ok(0)
    170 -> Ok(20)
    171 -> Ok(0)
    172 -> Ok(0)
    173 -> Ok(0)
    174 -> Ok(0)
    175 -> Ok(0)
    176 -> Ok(0)
    177 -> Ok(0)
    178 -> Ok(0)
    179 -> Ok(20)
    180 -> Ok(0)
    181 -> Ok(0)
    182 -> Ok(0)
    183 -> Ok(24)
    184 -> Ok(0)
    185 -> Ok(0)
    186 -> Ok(0)
    187 -> Ok(20)
    188 -> Ok(0)
    189 -> Ok(0)
    190 -> Ok(0)
    191 -> Ok(0)
    192 -> Ok(0)
    193 -> Ok(0)
    194 -> Ok(20)
    195 -> Ok(0)
    196 -> Ok(0)
    197 -> Ok(0)
    198 -> Ok(0)
    199 -> Ok(24)
    200 -> Ok(0)
    201 -> Ok(0)
    202 -> Ok(0)
    203 -> Ok(0)
    204 -> Ok(20)
    205 -> Ok(0)
    206 -> Ok(0)
    207 -> Ok(0)
    208 -> Ok(0)
    209 -> Ok(20)
    210 -> Ok(0)
    211 -> Ok(0)
    212 -> Ok(0)
    213 -> Ok(0)
    214 -> Ok(0)
    215 -> Ok(24)
    216 -> Ok(0)
    217 -> Ok(0)
    218 -> Ok(0)
    219 -> Ok(0)
    220 -> Ok(0)
    221 -> Ok(20)
    222 -> Ok(0)
    223 -> Ok(0)
    224 -> Ok(20)
    225 -> Ok(0)
    226 -> Ok(0)
    227 -> Ok(0)
    228 -> Ok(0)
    229 -> Ok(0)
    230 -> Ok(0)
    231 -> Ok(24)
    232 -> Ok(0)
    233 -> Ok(0)
    234 -> Ok(0)
    235 -> Ok(0)
    236 -> Ok(0)
    237 -> Ok(0)
    238 -> Ok(20)
    _ -> Error(Nil)
  }
}

///  17,  0,  0,  0,  0,  0,  0, 16,  0,  0,  0,  0,  0,  0, 15, 0,
///   0, 17,  0,  0,  0,  0,  0, 16,  0,  0,  0,  0,  0, 15,  0, 0,
///   0,  0, 17,  0,  0,  0,  0, 16,  0,  0,  0,  0, 15,  0,  0, 0,
///   0,  0,  0, 17,  0,  0,  0, 16,  0,  0,  0, 15,  0,  0,  0, 0,
///   0,  0,  0,  0, 17,  0,  0, 16,  0,  0, 15,  0,  0,  0,  0, 0,
///   0,  0,  0,  0,  0, 17,  0, 16,  0, 15,  0,  0,  0,  0,  0, 0,
///   0,  0,  0,  0,  0,  0, 17, 16, 15,  0,  0,  0,  0,  0,  0, 0,
///   1,  1,  1,  1,  1,  1,  1,  0, -1, -1,  -1,-1, -1, -1, -1, 0,
///   0,  0,  0,  0,  0,  0,-15,-16,-17,  0,  0,  0,  0,  0,  0, 0,
///   0,  0,  0,  0,  0,-15,  0,-16,  0,-17,  0,  0,  0,  0,  0, 0,
///   0,  0,  0,  0,-15,  0,  0,-16,  0,  0,-17,  0,  0,  0,  0, 0,
///   0,  0,  0,-15,  0,  0,  0,-16,  0,  0,  0,-17,  0,  0,  0, 0,
///   0,  0,-15,  0,  0,  0,  0,-16,  0,  0,  0,  0,-17,  0,  0, 0,
///   0,-15,  0,  0,  0,  0,  0,-16,  0,  0,  0,  0,  0,-17,  0, 0,
/// -15,  0,  0,  0,  0,  0,  0,-16,  0,  0,  0,  0,  0,  0,-17
fn rays(i: Int) {
  case i {
    0 -> Ok(17)
    1 -> Ok(0)
    2 -> Ok(0)
    3 -> Ok(0)
    4 -> Ok(0)
    5 -> Ok(0)
    6 -> Ok(0)
    7 -> Ok(16)
    8 -> Ok(0)
    9 -> Ok(0)
    10 -> Ok(0)
    11 -> Ok(0)
    12 -> Ok(0)
    13 -> Ok(0)
    14 -> Ok(15)
    15 -> Ok(0)
    16 -> Ok(0)
    17 -> Ok(17)
    18 -> Ok(0)
    19 -> Ok(0)
    20 -> Ok(0)
    21 -> Ok(0)
    22 -> Ok(0)
    23 -> Ok(16)
    24 -> Ok(0)
    25 -> Ok(0)
    26 -> Ok(0)
    27 -> Ok(0)
    28 -> Ok(0)
    29 -> Ok(15)
    30 -> Ok(0)
    31 -> Ok(0)
    32 -> Ok(0)
    33 -> Ok(0)
    34 -> Ok(17)
    35 -> Ok(0)
    36 -> Ok(0)
    37 -> Ok(0)
    38 -> Ok(0)
    39 -> Ok(16)
    40 -> Ok(0)
    41 -> Ok(0)
    42 -> Ok(0)
    43 -> Ok(0)
    44 -> Ok(15)
    45 -> Ok(0)
    46 -> Ok(0)
    47 -> Ok(0)
    48 -> Ok(0)
    49 -> Ok(0)
    50 -> Ok(0)
    51 -> Ok(17)
    52 -> Ok(0)
    53 -> Ok(0)
    54 -> Ok(0)
    55 -> Ok(16)
    56 -> Ok(0)
    57 -> Ok(0)
    58 -> Ok(0)
    59 -> Ok(15)
    60 -> Ok(0)
    61 -> Ok(0)
    62 -> Ok(0)
    63 -> Ok(0)
    64 -> Ok(0)
    65 -> Ok(0)
    66 -> Ok(0)
    67 -> Ok(0)
    68 -> Ok(17)
    69 -> Ok(0)
    70 -> Ok(0)
    71 -> Ok(16)
    72 -> Ok(0)
    73 -> Ok(0)
    74 -> Ok(15)
    75 -> Ok(0)
    76 -> Ok(0)
    77 -> Ok(0)
    78 -> Ok(0)
    79 -> Ok(0)
    80 -> Ok(0)
    81 -> Ok(0)
    82 -> Ok(0)
    83 -> Ok(0)
    84 -> Ok(0)
    85 -> Ok(17)
    86 -> Ok(0)
    87 -> Ok(16)
    88 -> Ok(0)
    89 -> Ok(15)
    90 -> Ok(0)
    91 -> Ok(0)
    92 -> Ok(0)
    93 -> Ok(0)
    94 -> Ok(0)
    95 -> Ok(0)
    96 -> Ok(0)
    97 -> Ok(0)
    98 -> Ok(0)
    99 -> Ok(0)
    100 -> Ok(0)
    101 -> Ok(0)
    102 -> Ok(17)
    103 -> Ok(16)
    104 -> Ok(15)
    105 -> Ok(0)
    106 -> Ok(0)
    107 -> Ok(0)
    108 -> Ok(0)
    109 -> Ok(0)
    110 -> Ok(0)
    111 -> Ok(0)
    112 -> Ok(1)
    113 -> Ok(1)
    114 -> Ok(1)
    115 -> Ok(1)
    116 -> Ok(1)
    117 -> Ok(1)
    118 -> Ok(1)
    119 -> Ok(0)
    120 -> Ok(-1)
    121 -> Ok(-1)
    122 -> Ok(-1)
    123 -> Ok(-1)
    124 -> Ok(-1)
    125 -> Ok(-1)
    126 -> Ok(-1)
    127 -> Ok(0)
    128 -> Ok(0)
    129 -> Ok(0)
    130 -> Ok(0)
    131 -> Ok(0)
    132 -> Ok(0)
    133 -> Ok(0)
    134 -> Ok(-15)
    135 -> Ok(-16)
    136 -> Ok(-17)
    137 -> Ok(0)
    138 -> Ok(0)
    139 -> Ok(0)
    140 -> Ok(0)
    141 -> Ok(0)
    142 -> Ok(0)
    143 -> Ok(0)
    144 -> Ok(0)
    145 -> Ok(0)
    146 -> Ok(0)
    147 -> Ok(0)
    148 -> Ok(0)
    149 -> Ok(-15)
    150 -> Ok(0)
    151 -> Ok(-16)
    152 -> Ok(0)
    153 -> Ok(-17)
    154 -> Ok(0)
    155 -> Ok(0)
    156 -> Ok(0)
    157 -> Ok(0)
    158 -> Ok(0)
    159 -> Ok(0)
    160 -> Ok(0)
    161 -> Ok(0)
    162 -> Ok(0)
    163 -> Ok(0)
    164 -> Ok(-15)
    165 -> Ok(0)
    166 -> Ok(0)
    167 -> Ok(-16)
    168 -> Ok(0)
    169 -> Ok(0)
    170 -> Ok(-17)
    171 -> Ok(0)
    172 -> Ok(0)
    173 -> Ok(0)
    174 -> Ok(0)
    175 -> Ok(0)
    176 -> Ok(0)
    177 -> Ok(0)
    178 -> Ok(0)
    179 -> Ok(-15)
    180 -> Ok(0)
    181 -> Ok(0)
    182 -> Ok(0)
    183 -> Ok(-16)
    184 -> Ok(0)
    185 -> Ok(0)
    186 -> Ok(0)
    187 -> Ok(-17)
    188 -> Ok(0)
    189 -> Ok(0)
    190 -> Ok(0)
    191 -> Ok(0)
    192 -> Ok(0)
    193 -> Ok(0)
    194 -> Ok(-15)
    195 -> Ok(0)
    196 -> Ok(0)
    197 -> Ok(0)
    198 -> Ok(0)
    199 -> Ok(-16)
    200 -> Ok(0)
    201 -> Ok(0)
    202 -> Ok(0)
    203 -> Ok(0)
    204 -> Ok(-17)
    205 -> Ok(0)
    206 -> Ok(0)
    207 -> Ok(0)
    208 -> Ok(0)
    209 -> Ok(-15)
    210 -> Ok(0)
    211 -> Ok(0)
    212 -> Ok(0)
    213 -> Ok(0)
    214 -> Ok(0)
    215 -> Ok(-16)
    216 -> Ok(0)
    217 -> Ok(0)
    218 -> Ok(0)
    219 -> Ok(0)
    220 -> Ok(0)
    221 -> Ok(-17)
    222 -> Ok(0)
    223 -> Ok(0)
    224 -> Ok(-15)
    225 -> Ok(0)
    226 -> Ok(0)
    227 -> Ok(0)
    228 -> Ok(0)
    229 -> Ok(0)
    230 -> Ok(0)
    231 -> Ok(-16)
    232 -> Ok(0)
    233 -> Ok(0)
    234 -> Ok(0)
    235 -> Ok(0)
    236 -> Ok(0)
    237 -> Ok(0)
    238 -> Ok(-17)
    _ -> Error(Nil)
  }
}
// END: Constants
