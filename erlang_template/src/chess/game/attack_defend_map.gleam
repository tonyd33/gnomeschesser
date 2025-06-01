import chess/piece
import chess/player
import chess/square
import gleam/dict
import gleam/int
import gleam/list
import gleam/set
import glearray
import util/yielder

type Board =
  dict.Dict(square.Square, piece.Piece)

pub type AttackDefendMap {
  AttackDefendMap(data: Data)
}

type Data =
  glearray.Array(List(#(square.Square, piece.Piece)))

pub fn get(
  attack_defend_map: AttackDefendMap,
  square: square.Square,
) -> List(#(square.Square, piece.Piece)) {
  let assert Ok(attacker_squares) =
    glearray.get(attack_defend_map.data, square.to_index(square))
  attacker_squares
}

pub fn new(board: Board) -> AttackDefendMap {
  // traverse the rays and take it
  // include the first piece hit if it exists
  // regardless of player
  let take_until_hit = fn(rays: List(List(square.Square))) {
    use acc, ray <- list.fold(rays, [])
    use acc, to <- list.fold_until(ray, acc)
    [to, ..acc]
    |> case dict.has_key(board, to) {
      False -> list.Continue
      True -> list.Stop
    }
  }
  let data = glearray.from_list(list.repeat([], 64))
  board
  |> dict.fold(data, fn(data, from, piece) {
    // Get squares that are being attacked by from
    let attacked_squares = case piece.symbol {
      piece.Bishop -> square.bishop_rays(from) |> take_until_hit
      piece.Queen -> square.queen_rays(from) |> take_until_hit
      piece.Rook -> square.rook_rays(from) |> take_until_hit
      piece.King -> square.king_moves(from)
      piece.Knight -> square.knight_moves(from)
      piece.Pawn -> square.pawn_capture_moves(from, piece.player)
    }
    // insert into the attack defend map
    use data, to <- list.fold(attacked_squares, data)
    // TODO: we can use try_update to make this slightly more efficient
    let assert Ok(data) = {
      let to_index = square.to_index(to)
      let assert Ok(attackers) = glearray.get(data, to_index)
      let attackers = [#(from, piece), ..attackers]
      glearray.copy_set(data, to_index, attackers)
    }

    data
  })
  |> AttackDefendMap(data: _)
}

/// Update the AttackDefendMap such that
/// piece at square is removed from the board
pub fn delete(
  attack_defend_map: AttackDefendMap,
  board: Board,
  square: square.Square,
  piece: piece.Piece,
) -> AttackDefendMap {
  let data: Data = attack_defend_map.data
  // remove the attacks from the square itself
  let data = {
    let remove_squares = fn(data: Data, to_squares: List(square.Square)) {
      list.fold(to_squares, data, fn(data, to) {
        let to_index = square.to_index(to)
        let assert Ok(attackers) = glearray.get(data, to_index)
        let attackers =
          list.fold(attackers, [], fn(acc, x) {
            case x.0 != square {
              True -> [x, ..acc]
              False -> acc
            }
          })
        let assert Ok(data) = glearray.copy_set(data, to_index, attackers)
        data
      })
    }
    case piece.symbol {
      piece.Bishop ->
        square.bishop_rays(square) |> list.fold(data, remove_squares)
      piece.Queen ->
        square.queen_rays(square) |> list.fold(data, remove_squares)
      piece.Rook -> square.rook_rays(square) |> list.fold(data, remove_squares)
      piece.King -> square.king_moves(square) |> remove_squares(data, _)
      piece.Knight -> square.knight_moves(square) |> remove_squares(data, _)
      piece.Pawn ->
        square.pawn_capture_moves(square, piece.player)
        |> remove_squares(data, _)
    }
  }
  // then update the rays of any piece that is currently attacking the square
  let data = {
    let assert Ok(square_attackers) =
      glearray.get(data, square.to_index(square))

    use data, #(attacker_square, attacker_piece) <- list.fold(
      square_attackers,
      data,
    )
    case attacker_piece.symbol {
      // if the attacker is a non-slider, don't modify anything
      piece.Pawn | piece.King | piece.Knight -> data
      // otherwise, continue the ray from the current piece
      piece.Bishop | piece.Rook | piece.Queen -> {
        let #(offset, _) =
          square.ray_to_offset(from: attacker_square, to: square)
        // start iterating from the current square + offset and continue
        use data, current_square <- yielder.fold_until(
          yielder.iterate(square + offset, int.add(_, offset)),
          data,
        )

        case square.is_valid(current_square) {
          False -> list.Stop(data)
          True -> {
            let current_square_index = square.to_index(current_square)
            let assert Ok(attackers) = glearray.get(data, current_square_index)
            let attackers = [#(attacker_square, attacker_piece), ..attackers]
            let assert Ok(data) =
              glearray.copy_set(data, current_square_index, attackers)

            data
            |> case dict.has_key(board, current_square) {
              False -> list.Continue
              True -> list.Stop
            }
          }
        }
      }
    }
  }

  AttackDefendMap(data:)
}

/// Update the AttackDefendMap such that
/// square is insert in the board
pub fn insert(
  attack_defend_map: AttackDefendMap,
  board: Board,
  square: square.Square,
  piece: piece.Piece,
) -> AttackDefendMap {
  let data: Data = attack_defend_map.data
  // insert the attacks from the square itself
  let data = {
    let insert_squares = fn(to_squares: List(square.Square), data: Data) {
      use data, to <- list.fold(to_squares, data)
      let to_index = square.to_index(to)
      let assert Ok(attackers) = glearray.get(data, to_index)
      let attackers = [#(square, piece), ..attackers]
      let assert Ok(data) = glearray.copy_set(data, to_index, attackers)
      data
    }

    let insert_squares_rays = fn(to_rays: List(List(square.Square)), data: Data) {
      use data, to_ray <- list.fold(to_rays, data)
      use data, to <- list.fold_until(to_ray, data)
      let to_index = square.to_index(to)

      let assert Ok(attackers) = glearray.get(data, to_index)
      let attackers = [#(square, piece), ..attackers]
      let assert Ok(data) = glearray.copy_set(data, to_index, attackers)
      data
      |> case dict.has_key(board, to) {
        False -> list.Continue
        True -> list.Stop
      }
    }

    case piece.symbol {
      piece.Bishop ->
        square.bishop_rays(square)
        |> insert_squares_rays(data)
      piece.Queen ->
        square.queen_rays(square)
        |> insert_squares_rays(data)
      piece.Rook ->
        square.rook_rays(square)
        |> insert_squares_rays(data)
      piece.King ->
        square.king_moves(square)
        |> insert_squares(data)
      piece.Knight ->
        square.knight_moves(square)
        |> insert_squares(data)
      piece.Pawn ->
        square.pawn_capture_moves(square, piece.player)
        |> insert_squares(data)
    }
  }

  // then update the rays of any piece that is currently attacking the square
  let data = {
    let assert Ok(square_attackers) =
      glearray.get(data, square.to_index(square))

    use data, #(attacker_square, attacker_piece) <- list.fold(
      square_attackers,
      data,
    )
    case attacker_piece.symbol {
      // if the attacker is a non-slider, don't modify anything
      piece.Pawn | piece.King | piece.Knight -> data
      // otherwise, continue the ray from the current piece
      piece.Bishop | piece.Rook | piece.Queen -> {
        let #(offset, _) =
          square.ray_to_offset(from: attacker_square, to: square)
        // if the offset is 0 something has gone wrong
        let assert True = offset != 0
        // start iterating from the current square + offset and continue
        use data, current_square <- yielder.fold_until(
          yielder.iterate(square + offset, int.add(_, offset)),
          data,
        )

        case square.is_valid(current_square) {
          False -> list.Stop(data)
          True -> {
            let current_square_index = square.to_index(current_square)

            let assert Ok(attackers) = glearray.get(data, current_square_index)
            let attackers =
              list.fold(attackers, [], fn(acc, x) {
                case x.0 != attacker_square {
                  True -> [x, ..acc]
                  False -> acc
                }
              })
            let assert Ok(data) =
              glearray.copy_set(data, current_square_index, attackers)
            data
            |> case dict.has_key(board, current_square) {
              False -> list.Continue
              True -> list.Stop
            }
          }
        }
      }
    }
  }

  AttackDefendMap(data:)
}

pub fn is_attacked_at(
  attack_defend_map: AttackDefendMap,
  at: square.Square,
  by: player.Player,
) -> Bool {
  get(attack_defend_map, at)
  |> list.any(fn(x) { { x.1 }.player == by })
}
