import chess/game
import chess/piece
import chess/player
import chess/square
import chess/util
import gleam/bool
import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set.{type Set}

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

pub fn is_capture(move: Move) -> Bool {
  set.contains(move.flags, Capture)
}

pub fn is_promotion(move: Move) -> Bool {
  set.contains(move.flags, Promotion)
}

pub fn is_en_passant(move: Move) -> Bool {
  set.contains(move.flags, EnPassant)
}

pub fn is_kingside_castle(move: Move) -> Bool {
  set.contains(move.flags, KingsideCastle)
}

pub fn is_queenside_castle(move: Move) -> Bool {
  set.contains(move.flags, QueensideCastle)
}

pub fn is_big_pawn(move: Move) -> Bool {
  set.contains(move.flags, BigPawn)
}

pub fn piece(move: Move) -> piece.Piece {
  piece.Piece(move.player, move.piece)
}

pub fn to_san(move: Move) -> SAN {
  move.san
}

/// Create a move from a SAN. The SAN must be strictly valid, including
/// disambiguation only when necessary, captures, check/checkmates, etc.
/// TODO: Possibly allow more flexibility
///
pub fn from_san(san: String, game: game.Game) -> Result(Move, Nil) {
  moves(game)
  |> list.find(fn(move) { to_san(move) == san })
}

/// Apply a move to a game. Moves should only be passed in with a `game` from
/// moves created with `from_san` or `moves` with the same `game`.
///
pub fn apply(move: Move, game: game.Game) -> Result(game.Game, Nil) {
  let Move(player, from, to, piece, _, promotion, _, _) = move
  let fullmove_number = game.fullmove_number(game)
  let halfmove_clock = game.halfmove_clock(game)
  let history = game.history(game)
  let castling_availability = game.castling_availability(game)

  use from_square <- result.try(square.algebraic(from))
  use to_square <- result.try(square.algebraic(to))

  // If we're debugging, we'll purposely be more strict to ensure correctness.
  // When actually competing though, we don't want the program to crash, even
  // if something's incorrect though.
  // #ifdef DEBUG
  validate_move(move, game)
  // #endif

  let is_kingside_castle = is_kingside_castle(move)
  let is_queenside_castle = is_queenside_castle(move)
  let is_en_passant = is_en_passant(move)
  let is_big_pawn = is_big_pawn(move)
  let is_capture = is_capture(move)

  let next_en_passant_target_square = case is_big_pawn {
    True -> {
      let offset = case player {
        player.White -> 16
        player.Black -> -16
      }
      let square = square.algebraic(to + offset)
      // #ifdef DEBUG
      let assert Ok(_) = square
      // #endif
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
    game.board(game)
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
      use castling_from_piece <- result.try(game.piece_at(
        game,
        castling_from_square,
      ))

      Ok(
        next_board
        |> dict.delete(castling_from_square)
        |> dict.insert(castling_to_square, castling_from_piece),
      )
    }
  })

  Ok(game.new(
    board: next_board,
    active_color: next_player,
    castling_availability: next_castling_availability,
    en_passant_target_square: next_en_passant_target_square,
    halfmove_clock: next_halfmove_clock,
    fullmove_number: next_fullmove_number,
    history: next_history,
  ))
}

pub fn moves(game: game.Game) -> List(Move) {
  let moves = internal_moves(game)
  moves
  |> list.map(internal_move_to_move(_, moves))
}

/// Validate a move is internally consistent. If it's not, the program will
/// crash. Use this only when debugging.
///
fn validate_move(move: Move, game: game.Game) -> Nil {
  let Move(player, from, to, piece, captured, promotion, _, _) = move
  let opponent = player.opponent(player)

  let assert Ok(from_square) = square.algebraic(from)
  let assert Ok(to_square) = square.algebraic(to)

  // It should be our turn
  let assert True = player == game.turn(game)

  // Piece should match what was stated in move
  let assert Ok(_) =
    game.piece_at(game, from_square)
    |> util.assert_result(
      fn(actual_piece) {
        actual_piece.symbol == piece && actual_piece.player == player
      },
      fn(_) { Nil },
    )

  // Promotion piece must match flag
  let assert True = case promotion {
    Some(_) -> is_promotion(move)
    None -> True
  }

  // Capture must match flag
  let assert True = case captured {
    Some(_) -> is_capture(move)
    None -> True
  }

  // Capture must match actual piece
  let assert True = case captured {
    Some(captured_piece) -> {
      let assert Ok(real_piece) = game.piece_at(game, to_square)
      real_piece.symbol == captured_piece && real_piece.player == opponent
    }
    None -> True
  }

  // Can't be kingside *and* queenside castle at the same time!
  let assert True =
    bool.nand(is_kingside_castle(move), is_queenside_castle(move))

  // is_en_passant implies is_capture
  let assert True = !is_en_passant(move) || is_capture(move)

  Nil
}

fn internal_moves(game: game.Game) -> List(InternalMove) {
  game
  |> game.pieces
  |> list.fold([], fn(moves, x) {
    let #(square, piece) = x
    let us = game.turn(game)
    // Not our piece
    use <- bool.guard(piece.player != us, moves)

    let from = square.ox88(square)
    let standard_moves = case piece.symbol {
      piece.Pawn -> {
        let offsets: List(Int) = pawn_offsets(piece.player)
        let assert [single, double, x1, x2] = offsets

        let single_jump_moves = {
          let to = from + single
          let single_jump =
            square.algebraic(to)
            |> result.map(game.square_empty(game, _))
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
          [single_jump]
        }

        let double_jump_moves = {
          let to = from + double
          let double_jump_moves =
            square.algebraic(to)
            // Ensure this square our second rank
            |> util.assert_result(
              fn(_) { { 8 - square.rank(from) } == second_rank(us) },
              fn(_) { Nil },
            )
            |> result.map(game.square_empty(game, _))
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
          [double_jump_moves]
        }

        let make_x_moves = fn(jump) {
          let to = from + jump
          let standard_x_move =
            square.algebraic(to)
            |> result.try(game.piece_at(game, _))
            |> util.assert_result(fn(x) { x.player != us }, fn(_) { Nil })
            |> result.map(fn(_) {
              InternalMove(
                player: us,
                from: from,
                to: to,
                piece: piece.Pawn,
                captured: Some(piece.Pawn),
                promotion: None,
                flags: set.from_list([Capture]),
              )
            })

          let ep_move =
            square.algebraic(to)
            |> util.assert_result(
              fn(to_alg) {
                game.en_passant_target_square(game)
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
          list.flatten([
            single_jump_moves,
            double_jump_moves,
            x1_moves,
            x2_moves,
          ])
          |> list.filter_map(fn(x) { x })
          |> list.flat_map(fan_promotion_moves)

        pawn_moves
      }
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

    // TODO: Add castling moves for King
    // TODO: Cant do a move that puts us in check

    let moves = moves |> list.append(standard_moves)

    // let castle_moves = {
    //   let castling_availability = set.from_list(game.castling_availability)
    //   let kingside = {
    //     use <- bool.guard(
    //       !set.contains(castling_availability, #(us, game.KingSide)),
    //       Error(Nil),
    //     )
    //   }
    //   let queenside = {
    //     todo
    //     use <- bool.guard(
    //       !set.contains(castling_availability, #(us, game.QueenSide)),
    //       Error(Nil),
    //     )
    //     todo
    //   }
    //   [kingside, queenside]
    // }

    moves
  })
}

/// Cast a "ray" from `from` in the `offset` direction and collect positions.
/// Execution terminates when:
/// - We hit a piece
/// - We are no longer on the board
/// - We have travelled more than `max_depth` times
///
fn collect_ray_moves(
  game: game.Game,
  from_piece: piece.PieceSymbol,
  from: Int,
  offset: Int,
  max_depth: Int,
) -> List(InternalMove) {
  collect_ray_moves_inner(game, from_piece, from, offset, 1, max_depth, [])
}

fn collect_ray_moves_inner(
  game: game.Game,
  from_piece: piece.PieceSymbol,
  from: Int,
  offset: Int,
  depth: Int,
  max_depth: Int,
  moves: List(InternalMove),
) -> List(InternalMove) {
  let us = game.turn(game)

  use <- bool.guard(depth > max_depth, moves)

  let to = from + { offset * depth }
  case square.algebraic(to) {
    Error(_) -> moves
    Ok(square) ->
      case game.piece_at(game, square) {
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

  // TODO: Handle check/checkmate. Maybe? It might not be strictly necessary
  undecorated_san
}

/// THIS SHOULD ONLY BE USED FOR MOVES THAT WERE GENERATED BY `internal_moves`
/// INCORRECT USAGE OF THIS FUNCTION WILL CRASH THE PROGRAM. YOU HAVE BEEN
/// WARNED.
///
fn internal_move_to_move(
  move: InternalMove,
  all_moves: List(InternalMove),
) -> Move {
  let san = internal_move_to_san(move, all_moves)
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
    player.White -> [#(square.A1, game.QueenSide), #(square.H1, game.KingSide)]
    player.Black -> [#(square.A8, game.QueenSide), #(square.H8, game.KingSide)]
  }
}
// END: Constants
