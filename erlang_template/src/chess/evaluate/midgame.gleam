import chess/evaluate/common.{type SidedScore, SidedScore}
import chess/evaluate/psqt
import chess/game
import chess/move
import chess/piece
import chess/player
import chess/square
import gleam/bool
import gleam/list
import gleam/option.{Some}
import gleam/result

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
