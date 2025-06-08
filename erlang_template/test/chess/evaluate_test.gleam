import chess/evaluate
import chess/evaluate/midgame
import chess/evaluate/pawn_structure
import chess/game
import chess/player
import gleeunit/should
import util/xint

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
  {
    midgame.king_pawn_shield(game1, player.White)
    > midgame.king_pawn_shield(game2, player.White)
  }
  |> should.equal(True)
  {
    midgame.king_pawn_shield(game2, player.White)
    > midgame.king_pawn_shield(game3, player.White)
  }
  |> should.equal(True)

  // Similar for black queenside castle
  let assert Ok(game1) =
    game.load_fen(
      "2kr1bnr/pppppppp/8/4q3/5n2/2NB1b2/PPPPPPPP/RNBQ1RK1 b - - 0 1",
    )
  let assert Ok(game2) =
    game.load_fen(
      "2kr1bnr/p3pppp/3p4/1pp1q3/5n2/2NB1b2/PPPPPPPP/RNBQ1RK1 b - - 0 1",
    )
  {
    midgame.king_pawn_shield(game1, player.Black)
    < midgame.king_pawn_shield(game2, player.Black)
  }
  |> should.equal(True)
}

pub fn evaluate_regression_test() {
  let assert Ok(game1) = game.load_fen(game.start_fen)
  let assert Ok(game2) =
    game.load_fen(
      "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
    )
  let assert Ok(game3) =
    game.load_fen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
  let assert Ok(game4) =
    game.load_fen("8/8/8/7p/8/2b2kPp/3p1P2/4N1K1 b - - 1 63")

  evaluate.game(game1) |> should.equal(xint.from_int(3))
  evaluate.game(game2) |> should.equal(xint.from_int(15))
  evaluate.game(game3) |> should.equal(xint.from_int(-4))
  evaluate.game(game4) |> should.equal(xint.from_int(-57))
}

pub fn evaluate_pawn_structure_test() {
  let assert Ok(game1) = game.load_fen(game.start_fen)
  let assert Ok(game2) =
    game.load_fen(
      "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
    )
  let assert Ok(game3) =
    game.load_fen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")
  let assert Ok(game4) =
    game.load_fen("8/8/8/7p/8/2b2kPp/3p1P2/4N1K1 b - - 1 63")
  let assert Ok(game5) =
    game.load_fen("8/8/8/P2P3p/PP1P4/1Pb2kPp/2pp1P2/4N1K1 b - - 1 63")

  pawn_structure.evaluate(game1, 1.0) |> should.equal(0.0)
  pawn_structure.evaluate(game2, 1.0) |> should.equal(27.0)
  pawn_structure.evaluate(game3, 1.0) |> should.equal(-60.0)
  pawn_structure.evaluate(game4, 1.0) |> should.equal(28.0)
  pawn_structure.evaluate(game5, 1.0) |> should.equal(-329.0)

  pawn_structure.evaluate(game1, 0.0) |> should.equal(0.0)
  pawn_structure.evaluate(game2, 0.0) |> should.equal(13.0)
  pawn_structure.evaluate(game3, 0.0) |> should.equal(-57.0)
  pawn_structure.evaluate(game4, 0.0) |> should.equal(-19.0)
  pawn_structure.evaluate(game5, 0.0) |> should.equal(-604.0)
}

pub fn evaluate_count_pawns_close_test() {
  let assert Ok(game) = game.load_fen("4k3/8/8/8/8/8/3PPP2/4K3 w - - 0 1")
  midgame.count_pawns_close(game, player.White)
  |> should.equal(3)

  let assert Ok(game) = game.load_fen("4k3/8/8/8/8/3P4/4PP2/4K3 w - - 0 1")
  midgame.count_pawns_close(game, player.White)
  |> should.equal(2)

  let assert Ok(game) = game.load_fen("8/8/4k3/3ppp2/8/3P4/4PP2/4K3 w - - 0 1")
  midgame.count_pawns_close(game, player.Black)
  |> should.equal(3)

  let assert Ok(game) = game.load_fen("8/8/4k3/5p2/3pp3/3P4/4PP2/4K3 w - - 0 1")
  midgame.count_pawns_close(game, player.Black)
  |> should.equal(1)
}

pub fn evaluate_count_pawns_close_far_test() {
  let assert Ok(game) = game.load_fen("4k3/5p2/3pp3/8/8/3P4/4PP2/4K3 w - - 0 1")
  midgame.count_pawns_far(game, player.White)
  |> should.equal(1)

  let assert Ok(game) = game.load_fen("4k3/5p2/3pp3/8/8/3P4/4PP2/4K3 w - - 0 1")
  midgame.count_pawns_far(game, player.Black)
  |> should.equal(2)
}
