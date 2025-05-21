import chess/evaluate/common
import chess/evaluate/psqt
import chess/game
import chess/move
import chess/piece
import chess/player
import chess/square
import gleam/bool
import gleam/int
import gleam/list
import gleam/result
import util/result_addons

pub fn psqt(pieces: List(#(square.Square, piece.Piece))) {
  pieces
  |> list.fold(0, fn(acc, square_pieces) {
    psqt.get_psq_score(square_pieces.1, square_pieces.0, common.MidGame) + acc
  })
}

/// Calculate a [mobility score](https://www.chessprogramming.org/Mobility).
///
/// Roughly, we want to capture the idea that "the more choices we have at
/// our disposal, the stronger our position."
///
/// This is implemented in a similar fashion: for every move, it counts
/// positively towards the mobility score and is weighted by the piece.
/// TODO: do both side's mobility
pub fn mobility(
  moves: List(move.Move(move.ValidInContext)),
  side: player.Player,
) -> Int {
  // TODO: use a cached version of getting moves somehow?
  list.fold(moves, 0, fn(mobility_score, move) {
    let move_context = move.get_context(move)
    case move_context.piece.symbol {
      piece.Pawn | piece.Knight | piece.King -> 0
      piece.Bishop -> 125
      piece.Rook -> 60
      piece.Queen -> 25
    }
    + mobility_score
  })
  * common.player(side)
  / 10
}

/// Evaluate king safety score with a pawn shield
/// TODO: check both sides
pub fn king_pawn_shield(game: game.Game) -> Int {
  let us = game.turn(game)
  let assert Ok(#(king_square, _)) = game.find_player_king(game, us)

  // Pawn shield: When the king has castled, it is important to preserve
  // pawns next to it, in order to protect it against the assault. Generally
  // speaking, it is best to keep the pawns unmoved or possibly moved up one
  // square. The lack of a shielding pawn deserves a penalty, even more so if
  // there is an open file next to the king.
  let pawn_shield_score = {
    // If we haven't even castled, no bonus or penalty will be applied for
    // the pawn shield score
    use <- bool.guard(!game.has_castled(game, us), 0)
    let king_rank = square.rank(king_square)
    let king_file = square.file(king_square)
    let rank_offset = case us {
      player.Black -> 1
      player.White -> -1
    }
    let our_pawn = piece.Piece(us, piece.Pawn)

    // TODO: Consider doing a smarter bitboard mask for these

    // This is the number of pawns that are 1 square away vertically
    let num_pawns_around_king_close =
      [
        square.from_rank_file(king_rank + rank_offset, king_file - 1),
        square.from_rank_file(king_rank + rank_offset, king_file),
        square.from_rank_file(king_rank + rank_offset, king_file + 1),
      ]
      |> list.filter_map(fn(rs) {
        result.map(rs, game.piece_exists_at(game, our_pawn, _))
        |> result_addons.expect_or(fn(x) { x }, fn(_) { Nil })
      })
      |> list.length
    // This is the number of pawns that are 2 squares away vertically
    // We start to give small penalties at this point
    let num_pawns_around_king_far =
      [
        square.from_rank_file(king_rank + rank_offset + 1, king_file - 1),
        square.from_rank_file(king_rank + rank_offset + 1, king_file),
        square.from_rank_file(king_rank + rank_offset + 1, king_file + 1),
      ]
      |> list.filter_map(fn(rs) {
        result.map(rs, game.piece_exists_at(game, our_pawn, _))
        |> result_addons.expect_or(fn(x) { x }, fn(_) { Nil })
      })
      |> list.length
    let num_pawns_around_king =
      num_pawns_around_king_close + num_pawns_around_king_far

    // TODO: Simplify math
    let penalty = case num_pawns_around_king_close {
      // If all three pawns are hugging the king closely, then no penalty is
      // incurred
      3 -> 0
      _ ->
        case num_pawns_around_king {
          // If all three pawns are still around the king, then some penalty is
          // incurred for the pawns that are far
          3 -> num_pawns_around_king_far
          // This means there are pawns that are very distant from the king!
          // For each pawn very distant from the king, apply a *harsh* penalty.
          _ -> {
            let num_pawns_distant = 3 - num_pawns_around_king

            { num_pawns_distant * 10 } + num_pawns_around_king_far
          }
        }
    }

    // Score is -penalty
    int.negate(penalty)
  }

  // let's ballpark the pawn shield should range around 100-200 centipawns
  pawn_shield_score * 60
}
