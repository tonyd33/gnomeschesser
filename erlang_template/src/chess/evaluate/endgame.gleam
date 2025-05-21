import chess/evaluate/common
import chess/evaluate/psqt
import chess/piece
import chess/square
import gleam/list

pub fn psqt(pieces: List(#(square.Square, piece.Piece))) {
  pieces
  |> list.fold(0, fn(acc, square_pieces) {
    psqt.get_psq_score(square_pieces.1, square_pieces.0, common.EndGame) + acc
  })
}
