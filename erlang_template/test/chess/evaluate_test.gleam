import chess/evaluate/midgame
import chess/game
import gleeunit/should

pub fn king_pawn_shield_test() {
  // Pawns are all close to king after he castled
  //    +------------------------+
  //  8 | ♜  ♞  ♝  ♛  ♚  ♝  ♞  ♜ |
  //  7 | ♟  ♟  ♟  ♟  ♟  ♟  ♟  ♟ |
  //  6 | .  .  .  .  .  .  .  . |
  //  5 | .  .  .  .  .  .  .  . |
  //  4 | .  .  .  .  .  .  .  . |
  //  3 | .  .  .  ♗  .  ♘  .  . |
  //  2 | ♙  ♙  ♙  ♙  ♙  ♙  ♙  ♙ |
  //  1 | ♖  ♘  ♗  ♕  .  ♖  ♔  . |
  //    +------------------------+
  //      a  b  c  d  e  f  g  h
  let assert Ok(game1) =
    game.load_fen("rnbqkbnr/pppppppp/8/8/8/3B1N2/PPPPPPPP/RNBQ1RK1 w kq - 0 1")

  // This is still ok, but slightly worse than before because one of the pawns
  // drifted away
  //    +------------------------+
  //  8 | ♜  ♞  ♝  ♛  ♚  ♝  ♞  ♜ |
  //  7 | ♟  ♟  ♟  ♟  ♟  ♟  ♟  ♟ |
  //  6 | .  .  .  .  .  .  .  . |
  //  5 | .  .  .  .  .  .  .  . |
  //  4 | .  .  .  .  .  .  .  . |
  //  3 | .  .  ♘  ♗  .  ♙  .  . |
  //  2 | ♙  ♙  ♙  ♙  ♙  .  ♙  ♙ |
  //  1 | ♖  ♘  ♗  ♕  .  ♖  ♔  . |
  //    +------------------------+
  //      a  b  c  d  e  f  g  h
  let assert Ok(game2) =
    game.load_fen("rnbqkbnr/pppppppp/8/8/8/2NB1P2/PPPPP1PP/RNBQ1RK1 w kq - 0 1")

  // Ok, this is getting really bad!
  //    +------------------------+
  //  8 | ♜  ♞  ♝  ♛  ♚  ♝  ♞  ♜ |
  //  7 | ♟  ♟  ♟  ♟  ♟  ♟  ♟  ♟ |
  //  6 | .  .  .  .  .  .  .  . |
  //  5 | .  .  .  .  .  .  .  . |
  //  4 | .  .  .  .  .  .  ♙  . |
  //  3 | .  .  ♘  ♗  .  ♙  .  . |
  //  2 | ♙  ♙  ♙  ♙  ♙  .  .  ♙ |
  //  1 | ♖  ♘  ♗  ♕  .  ♖  ♔  . |
  //    +------------------------+
  //      a  b  c  d  e  f  g  h
  let assert Ok(game3) =
    game.load_fen(
      "rnbqkbnr/pppppppp/8/8/6P1/2NB1P2/PPPPP2P/RNBQ1RK1 w kq - 0 1",
    )

  { midgame.king_pawn_shield(game1) >= midgame.king_pawn_shield(game2) }
  |> should.equal(True)
  { midgame.king_pawn_shield(game2) >= midgame.king_pawn_shield(game3) }
  |> should.equal(True)

  // Similar for black queenside castle
  let assert Ok(game1) =
    game.load_fen(
      "2kr1bnr/pppppppp/8/4q3/5n2/2NB1b2/PPPPPPPP/RNBQ1RK1 b k - 0 1",
    )
  let assert Ok(game2) =
    game.load_fen(
      "2kr1bnr/p3pppp/8/1pppq3/5n2/2NB1b2/PPPPPPPP/RNBQ1RK1 b k - 0 1",
    )
  { midgame.king_pawn_shield(game1) >= midgame.king_pawn_shield(game2) }
  |> should.equal(True)
}
