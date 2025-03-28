//// All of these test boards include kings on both sides because
//// it's necessary for a board to be valid. We want to remain agnostic
//// to whether our FEN loader accepts valid boards.
////
//// Additionally, the correct moves are determined using chess.js. To add a
//// test case yourself, follow the instructions:
//// 1. `git clone https://github.com/jhlywa/chess.js`
//// 2. Install dependencies and automatically build with `npm i`
//// 3. Create a file at the repo root:
//// ```js
//// const {Chess} = require('./dist/cjs/chess.js')
//// //replace with your fen
//// const game = new Chess("7k/8/2P1p3/8/3N4/8/8/7K w - - 0 1")
//// const moves = game.moves().sort() // sort for testing stability
//// console.log(game.ascii())
//// console.log(JSON.stringify(moves))
//// ```
//// 4. `node file.js` to get the correct moves for the FEN and copy it here

import chess/game.{load_fen}
import chess/move
import gleam/list
import gleam/string
import gleeunit/should

// BEGIN: move.moves tests

/// Basic knight test.
///    +------------------------+
///  8 | .  .  .  .  .  .  .  k |
///  7 | .  .  .  .  .  .  .  . |
///  6 | .  .  P  .  p  .  .  . |
///  5 | .  .  .  .  .  .  .  . |
///  4 | .  .  .  N  .  .  .  . |
///  3 | .  .  .  .  .  .  .  . |
///  2 | .  .  .  .  .  .  .  . |
///  1 | .  .  .  .  .  .  .  K |
///    +------------------------+
///      a  b  c  d  e  f  g  h
pub fn moves_knight_test() {
  let assert Ok(game) = load_fen("7k/8/2P1p3/8/3N4/8/8/7K w - - 0 1")

  move.moves(game)
  |> list.map(move.to_san)
  |> list.sort(string.compare)
  |> should.equal([
    "Kg1", "Kg2", "Kh2", "Nb3", "Nb5", "Nc2", "Ne2", "Nf3", "Nf5", "Nxe6", "c7",
  ])
}

/// Basic bishop test.
///    +------------------------+
///  8 | .  .  .  .  .  .  .  k |
///  7 | .  .  .  .  .  .  .  . |
///  6 | .  .  .  .  .  .  .  . |
///  5 | .  .  .  .  .  .  .  . |
///  4 | .  .  .  .  B  .  .  . |
///  3 | .  .  .  .  .  .  .  . |
///  2 | .  .  .  .  .  .  .  . |
///  1 | .  .  .  .  .  .  .  K |
///    +------------------------+
///      a  b  c  d  e  f  g  h
pub fn moves_bishop_test() {
  let assert Ok(game) = load_fen("7k/8/8/8/4B3/8/8/7K w - - 0 1")

  move.moves(game)
  |> list.map(move.to_san)
  |> list.sort(string.compare)
  |> should.equal([
    "Ba8", "Bb1", "Bb7", "Bc2", "Bc6", "Bd3", "Bd5", "Bf3", "Bf5", "Bg2", "Bg6",
    "Bh7", "Kg1", "Kg2", "Kh2",
  ])
}

/// Basic queen test. We add extra pieces to protect the black king because we
/// *don't* want to put the king in check. A check adds "+" to the SAN string,
/// which we'll test in other tests.
///   +------------------------+
/// 8 | .  .  .  .  .  .  b  k |
/// 7 | .  .  .  .  .  .  p  p |
/// 6 | .  .  .  .  .  p  .  . |
/// 5 | .  .  .  .  .  .  .  . |
/// 4 | .  .  .  Q  .  .  .  . |
/// 3 | .  .  P  .  .  .  .  . |
/// 2 | .  .  .  .  .  .  .  . |
/// 1 | .  .  .  .  .  .  .  K |
///   +------------------------+
///     a  b  c  d  e  f  g  h
pub fn moves_queen_test() {
  let assert Ok(game) = load_fen("6pk/6pp/5p2/8/3Q4/2P5/8/7K w - - 0 1")

  move.moves(game)
  |> list.map(move.to_san)
  |> list.sort(string.compare)
  |> should.equal([
    "Kg1", "Kg2", "Kh2", "Qa4", "Qa7", "Qb4", "Qb6", "Qc4", "Qc5", "Qd1", "Qd2",
    "Qd3", "Qd5", "Qd6", "Qd7", "Qd8", "Qe3", "Qe4", "Qe5", "Qf2", "Qf4", "Qg1",
    "Qg4", "Qh4", "Qxf6", "c4",
  ])
}

///    +------------------------+
///  8 | .  .  .  .  .  .  .  k |
///  7 | .  .  .  .  .  .  .  . |
///  6 | .  .  .  .  .  .  .  . |
///  5 | .  .  .  .  .  .  .  . |
///  4 | .  .  .  .  .  .  .  . |
///  3 | .  P  p  .  p  .  .  . |
///  2 | P  .  .  P  .  .  .  . |
///  1 | .  .  .  .  .  .  .  K |
///    +------------------------+
///      a  b  c  d  e  f  g  h
pub fn moves_pawn_test() {
  let assert Ok(game) = load_fen("7k/8/8/8/8/1Pp1p3/P2P4/7K w Aa - 0 1")

  move.moves(game)
  |> list.map(move.to_san)
  |> list.sort(string.compare)
  |> should.equal([
    "Kg1", "Kg2", "Kh2", "a3", "a4", "b4", "d3", "d4", "dxc3", "dxe3",
  ])
}

///    +------------------------+
///  8 | .  .  .  n  .  .  .  . |
///  7 | .  .  P  .  .  .  .  k |
///  6 | .  .  .  .  .  .  .  . |
///  5 | .  .  .  .  .  .  .  . |
///  4 | .  .  .  .  .  .  .  . |
///  3 | .  .  .  .  .  .  .  . |
///  2 | .  .  .  .  .  .  .  . |
///  1 | .  .  .  .  .  .  .  K |
///    +------------------------+
///      a  b  c  d  e  f  g  h
pub fn moves_pawn_promotion_test() {
  let assert Ok(game) = load_fen("3n4/2P4k/8/8/8/8/8/7K w - - 0 1")

  move.moves(game)
  |> list.map(move.to_san)
  |> list.sort(string.compare)
  |> should.equal([
    "Kg1", "Kg2", "Kh2", "c8=B", "c8=N", "c8=Q", "c8=R", "cxd8=B", "cxd8=N",
    "cxd8=Q", "cxd8=R",
  ])
}

/// Ensure moves are properly disambiguated. Test both levels of
/// disambiguation: file and rank and file+rank.
/// Board inspired from: https://en.wikipedia.org/wiki/Algebraic_notation_(chess)#Disambiguating_moves
///    +------------------------+
///  8 | K  R  .  .  .  R  n  . |
///  7 | .  .  .  .  .  .  p  k |
///  6 | .  .  .  .  .  p  p  p |
///  5 | R  .  .  .  .  .  p  . |
///  4 | .  .  .  Q  .  .  Q  . |
///  3 | .  .  .  .  .  .  .  . |
///  2 | .  .  .  .  .  .  .  . |
///  1 | R  .  .  .  .  .  Q  . |
///    +------------------------+
///      a  b  c  d  e  f  g  h
pub fn moves_disambiguation_test() {
  let assert Ok(game) =
    load_fen("KR3Rn1/6pk/5ppp/R5p1/3Q2Q1/8/8/R5Q1 w - - 0 1")

  move.moves(game)
  |> list.map(move.to_san)
  |> list.sort(string.compare)
  |> should.equal([
    "Ka7", "Kb7", "Q1d1", "Q1g2", "Q1g3", "Q4g2", "Q4g3", "Qa4", "Qa7", "Qb1",
    "Qb2", "Qb4", "Qb6", "Qc1", "Qc3", "Qc4", "Qc5", "Qc8", "Qd2", "Qd3", "Qd5",
    "Qd6", "Qd8", "Qdd1", "Qdd7", "Qde3", "Qde4", "Qdf2", "Qdf4", "Qe1", "Qe2",
    "Qe5", "Qe6", "Qf1", "Qf3", "Qf5", "Qg4d1", "Qgd7", "Qge3", "Qge4", "Qgf2",
    "Qgf4", "Qh1", "Qh2", "Qh3", "Qh4", "Qh5", "Qxf6", "Qxg5", "R1a2", "R1a3",
    "R1a4", "R5a2", "R5a3", "R5a4", "Ra6", "Ra7", "Rab1", "Rab5", "Rb2", "Rb3",
    "Rb4", "Rb6", "Rb7", "Rbb1", "Rbb5", "Rbc8", "Rbd8", "Rbe8", "Rc1", "Rc5",
    "Rd1", "Rd5", "Re1", "Re5", "Rf1", "Rf5", "Rf7", "Rfc8", "Rfd8", "Rfe8",
    "Rxf6", "Rxg5", "Rxg8",
  ])
}

///    +------------------------+
///  8 | .  .  .  .  .  .  .  . |
///  7 | .  .  .  .  .  .  .  k |
///  6 | .  .  .  .  .  .  .  . |
///  5 | .  .  .  n  .  .  .  . |
///  4 | .  .  P  .  P  .  .  . |
///  3 | .  .  .  .  .  .  .  . |
///  2 | .  .  .  .  .  .  .  . |
///  1 | .  .  .  .  .  .  .  K |
///    +------------------------+
///      a  b  c  d  e  f  g  h
pub fn moves_disambiguation_pawn_test() {
  let assert Ok(game) = load_fen("8/7k/8/3n4/2P1P3/8/8/7K w - - 0 1")

  move.moves(game)
  |> list.map(move.to_san)
  |> list.sort(string.compare)
  |> should.equal(["Kg1", "Kg2", "Kh2", "c5", "cxd5", "e5", "exd5"])
}

/// Check/checkmates
///    +------------------------+
///  8 | .  r  .  .  .  .  .  k |
///  7 | .  .  .  .  .  .  .  . |
///  6 | .  .  .  .  .  .  .  . |
///  5 | .  .  .  .  .  .  .  . |
///  4 | .  .  .  .  .  .  .  . |
///  3 | .  .  .  .  .  .  .  . |
///  2 | r  .  .  .  .  .  .  . |
///  1 | .  .  .  .  .  .  .  K |
///    +------------------------+
///      a  b  c  d  e  f  g  h
pub fn moves_check_test() {
  let assert Ok(game) = load_fen("1r5k/8/8/8/8/8/r7/7K b - - 0 1")

  move.moves(game)
  |> list.map(move.to_san)
  |> list.sort(string.compare)
  |> should.equal([
    "Kg7", "Kg8", "Kh7", "Ra1+", "Ra3", "Ra4", "Ra5", "Ra6", "Ra7", "Raa8",
    "Rab2", "Rb1#", "Rb3", "Rb4", "Rb5", "Rb6", "Rb7", "Rba8", "Rbb2", "Rc2",
    "Rc8", "Rd2", "Rd8", "Re2", "Re8", "Rf2", "Rf8", "Rg2", "Rg8", "Rh2+",
  ])
}

/// Can't make moves that put king into check
///    +------------------------+
///  8 | .  .  .  .  .  .  r  k |
///  7 | .  .  .  .  .  .  .  r |
///  6 | .  .  .  .  .  .  .  . |
///  5 | .  .  .  .  .  .  .  . |
///  4 | .  .  .  .  .  .  .  . |
///  3 | .  .  .  .  .  .  .  B |
///  2 | .  .  .  .  .  .  .  . |
///  1 | .  .  .  .  .  .  .  K |
///    +------------------------+
///      a  b  c  d  e  f  g  h
pub fn moves_no_move_into_check_test() {
  let assert Ok(game) = load_fen("6rk/7r/8/8/8/7B/8/7K w - - 0 1")

  move.moves(game)
  |> list.map(move.to_san)
  |> list.sort(string.compare)
  |> should.equal(["Kh2"])
}

// END: move.moves tests

// BEGIN: move.apply tests

pub fn apply_basic_test() {
  let assert Ok(game) =
    load_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

  let assert Ok(move_e4) = move.from_san("e4", game)
  let assert Ok(game) = move.apply(move_e4, game)

  game
  |> game.to_fen
  |> should.equal("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
}
// END: move.apply tests
