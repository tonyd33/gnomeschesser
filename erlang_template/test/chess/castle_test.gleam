import chess/game/castle
import chess/move
import chess/player
import gleam/list
import gleeunit/should

pub fn move_king_castle_test() {
  [
    move.king_castle(player.White, castle.KingSide),
    move.king_castle(player.White, castle.QueenSide),
    move.king_castle(player.Black, castle.KingSide),
    move.king_castle(player.Black, castle.QueenSide),
  ]
  |> list.map(move.to_lan)
  |> should.equal(["e1g1", "e1c1", "e8g8", "e8c8"])
}
