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
pub fn mobility(game: game.Game, moves: List(move.Move(a))) -> Int {
  list.fold(moves, 0, fn(acc, move) {
    // TODO: shit, the piece is no longer stored in move for pseudolegal moves.
    // Put it back without breaking API or squashing interfaces and making
    // Johnny mad
    let assert Ok(piece) = game.piece_at(game, move.get_from(move))
    case piece.symbol {
      piece.Pawn | piece.Knight | piece.King -> 0
      piece.Bishop -> 125
      piece.Rook -> 60
      piece.Queen -> 25
    }
    * common.player(piece.player)
    + acc
  })
  / 10
}

/// Evaluate king safety score with a pawn shield
/// Positive is good for white, negative is good for black
pub fn king_pawn_shield(game: game.Game, side: player.Player) -> Int {
  let assert Ok(#(king_square, _)) = game.find_player_king(game, side)

  // Pawn shield: When the king has castled, it is important to preserve
  // pawns next to it, in order to protect it against the assault. Generally
  // speaking, it is best to keep the pawns unmoved or possibly moved up one
  // square. The lack of a shielding pawn deserves a penalty, even more so if
  // there is an open file next to the king.
  {
    // If we haven't even castled, no bonus will be applied for
    // the pawn shield score
    // TODO: this currently just check castling availability
    // We could have this be part of a more general king safety term?
    use <- bool.guard(!game.has_castled(game, side), 0)
    let king_rank = square.rank(king_square)
    let king_file = square.file(king_square)
    let rank_offset = case side {
      player.Black -> -1
      player.White -> 1
    }
    let our_pawn = piece.Piece(side, piece.Pawn)

    // TODO: Consider doing a smarter bitboard mask for these
    // This is the number of pawns that are 1 square away vertically
    let num_pawns_around_king_close =
      [
        square.from_rank_file(king_rank + rank_offset, king_file - 1),
        square.from_rank_file(king_rank + rank_offset, king_file),
        square.from_rank_file(king_rank + rank_offset, king_file + 1),
      ]
      |> list.count(fn(pawn_square) {
        pawn_square
        |> result.map(game.piece_exists_at(game, our_pawn, _))
        |> result.unwrap(False)
      })
    // This is the number of pawns that are 2 squares away vertically
    let num_pawns_around_king_far =
      [
        square.from_rank_file(king_rank + rank_offset * 2, king_file - 1),
        square.from_rank_file(king_rank + rank_offset * 2, king_file),
        square.from_rank_file(king_rank + rank_offset * 2, king_file + 1),
      ]
      |> list.count(fn(pawn_square) {
        pawn_square
        |> result.map(game.piece_exists_at(game, our_pawn, _))
        |> result.unwrap(False)
      })

    // instead of doing a penalty, we do a bonus
    // this also encourages the king to castle more rather than punishes

    // all 3 pawns close to the king would be about 120 centipawns
    { num_pawns_around_king_close * 40 }
    // all 3 pawns 1 away from the king would be about 30 centipawns
    + { num_pawns_around_king_far * 10 }
  }
  * common.player(side)
}
