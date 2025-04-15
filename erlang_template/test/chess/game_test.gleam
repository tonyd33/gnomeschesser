import chess/game.{load_fen}
import chess/piece
import chess/player
import chess/square
import gleam/dict
import gleam/list
import gleam/string
import gleeunit/should

// See: https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation#Examples
pub fn load_fen_starting_position_test() {
  let assert Ok(game) =
    load_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

  game
  |> game.pieces
  |> dict.from_list
  |> should.equal(
    [
      #(square.A1, piece.Piece(player.White, piece.Rook)),
      #(square.B1, piece.Piece(player.White, piece.Knight)),
      #(square.C1, piece.Piece(player.White, piece.Bishop)),
      #(square.D1, piece.Piece(player.White, piece.Queen)),
      #(square.E1, piece.Piece(player.White, piece.King)),
      #(square.F1, piece.Piece(player.White, piece.Bishop)),
      #(square.G1, piece.Piece(player.White, piece.Knight)),
      #(square.H1, piece.Piece(player.White, piece.Rook)),
      #(square.A2, piece.Piece(player.White, piece.Pawn)),
      #(square.B2, piece.Piece(player.White, piece.Pawn)),
      #(square.C2, piece.Piece(player.White, piece.Pawn)),
      #(square.D2, piece.Piece(player.White, piece.Pawn)),
      #(square.E2, piece.Piece(player.White, piece.Pawn)),
      #(square.F2, piece.Piece(player.White, piece.Pawn)),
      #(square.G2, piece.Piece(player.White, piece.Pawn)),
      #(square.H2, piece.Piece(player.White, piece.Pawn)),
      #(square.A8, piece.Piece(player.Black, piece.Rook)),
      #(square.B8, piece.Piece(player.Black, piece.Knight)),
      #(square.C8, piece.Piece(player.Black, piece.Bishop)),
      #(square.D8, piece.Piece(player.Black, piece.Queen)),
      #(square.E8, piece.Piece(player.Black, piece.King)),
      #(square.F8, piece.Piece(player.Black, piece.Bishop)),
      #(square.G8, piece.Piece(player.Black, piece.Knight)),
      #(square.H8, piece.Piece(player.Black, piece.Rook)),
      #(square.A7, piece.Piece(player.Black, piece.Pawn)),
      #(square.B7, piece.Piece(player.Black, piece.Pawn)),
      #(square.C7, piece.Piece(player.Black, piece.Pawn)),
      #(square.D7, piece.Piece(player.Black, piece.Pawn)),
      #(square.E7, piece.Piece(player.Black, piece.Pawn)),
      #(square.F7, piece.Piece(player.Black, piece.Pawn)),
      #(square.G7, piece.Piece(player.Black, piece.Pawn)),
      #(square.H7, piece.Piece(player.Black, piece.Pawn)),
    ]
    |> dict.from_list,
  )

  game
  |> game.castling_availability
  |> dict.from_list
  |> should.equal(
    [
      #(player.White, game.KingSide),
      #(player.White, game.QueenSide),
      #(player.Black, game.KingSide),
      #(player.Black, game.QueenSide),
    ]
    |> dict.from_list,
  )
}

// See: https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation#Examples
pub fn load_fen_e4_test() {
  let assert Ok(game) =
    load_fen("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")

  game
  |> game.pieces
  |> dict.from_list
  |> should.equal(
    [
      #(square.A1, piece.Piece(player.White, piece.Rook)),
      #(square.B1, piece.Piece(player.White, piece.Knight)),
      #(square.C1, piece.Piece(player.White, piece.Bishop)),
      #(square.D1, piece.Piece(player.White, piece.Queen)),
      #(square.E1, piece.Piece(player.White, piece.King)),
      #(square.F1, piece.Piece(player.White, piece.Bishop)),
      #(square.G1, piece.Piece(player.White, piece.Knight)),
      #(square.H1, piece.Piece(player.White, piece.Rook)),
      #(square.A2, piece.Piece(player.White, piece.Pawn)),
      #(square.B2, piece.Piece(player.White, piece.Pawn)),
      #(square.C2, piece.Piece(player.White, piece.Pawn)),
      #(square.D2, piece.Piece(player.White, piece.Pawn)),
      #(square.E4, piece.Piece(player.White, piece.Pawn)),
      #(square.F2, piece.Piece(player.White, piece.Pawn)),
      #(square.G2, piece.Piece(player.White, piece.Pawn)),
      #(square.H2, piece.Piece(player.White, piece.Pawn)),
      #(square.A8, piece.Piece(player.Black, piece.Rook)),
      #(square.B8, piece.Piece(player.Black, piece.Knight)),
      #(square.C8, piece.Piece(player.Black, piece.Bishop)),
      #(square.D8, piece.Piece(player.Black, piece.Queen)),
      #(square.E8, piece.Piece(player.Black, piece.King)),
      #(square.F8, piece.Piece(player.Black, piece.Bishop)),
      #(square.G8, piece.Piece(player.Black, piece.Knight)),
      #(square.H8, piece.Piece(player.Black, piece.Rook)),
      #(square.A7, piece.Piece(player.Black, piece.Pawn)),
      #(square.B7, piece.Piece(player.Black, piece.Pawn)),
      #(square.C7, piece.Piece(player.Black, piece.Pawn)),
      #(square.D7, piece.Piece(player.Black, piece.Pawn)),
      #(square.E7, piece.Piece(player.Black, piece.Pawn)),
      #(square.F7, piece.Piece(player.Black, piece.Pawn)),
      #(square.G7, piece.Piece(player.Black, piece.Pawn)),
      #(square.H7, piece.Piece(player.Black, piece.Pawn)),
    ]
    |> dict.from_list,
  )

  game
  |> game.castling_availability
  |> dict.from_list
  |> should.equal(
    [
      #(player.White, game.KingSide),
      #(player.White, game.QueenSide),
      #(player.Black, game.KingSide),
      #(player.Black, game.QueenSide),
    ]
    |> dict.from_list,
  )
}

pub fn load_fen_fail_test() {
  // has an extra row
  let assert Error(_) =
    load_fen("/rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
  // has an extra piece
  let assert Error(_) =
    load_fen("prnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
  // has an extra row + piece
  let assert Error(_) =
    load_fen("p/rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
}

///   +------------------------+
/// 8 | R  .  .  .  .  .  r  k |
/// 7 | .  .  B  .  .  .  p  p |
/// 6 | .  .  .  .  .  .  .  . |
/// 5 | .  .  .  Q  .  .  .  . |
/// 4 | .  .  .  .  .  .  .  . |
/// 3 | .  N  .  .  .  .  .  . |
/// 2 | .  .  .  .  .  .  .  . |
/// 1 | R  .  .  .  .  .  .  K |
///   +------------------------+
///     a  b  c  d  e  f  g  h
pub fn attackers_basic_test() {
  let assert Ok(game) = load_fen("R5rk/2B3pp/8/3Q4/8/1N6/8/R6K w - - 0 1")

  game
  |> game.attackers(square.A5)
  |> list.map(fn(x) { square.string(x.0) })
  |> list.sort(string.compare)
  |> should.equal(["a1", "a8", "b3", "c7", "d5"])
}

// All of these test boards include kings on both sides because
// it's necessary for a board to be valid. We want to remain agnostic
// to whether our FEN loader accepts valid boards.
//
// Additionally, the correct moves are determined using chess.js. To add a
// test case yourself, follow the instructions:
// 1. `git clone https://github.com/jhlywa/chess.js`
// 2. Install dependencies and automatically build with `npm i`
// 3. Create a file at the repo root:
// ```js
// const {Chess} = require('./dist/cjs/chess.js')
// //replace with your fen
// const game = new Chess("7k/8/2P1p3/8/3N4/8/8/7K w - - 0 1")
// const moves = game.moves().sort() // sort for testing stability
// console.log(game.ascii())
// console.log(JSON.stringify(moves))
// ```
// 4. `node file.js` to get the correct moves for the FEN and copy it here

/// Basic knight test.
/// Sanity check
///   +------------------------+
/// 8 | r  n  b  q  k  b  n  r |
/// 7 | p  p  p  p  p  p  p  p |
/// 6 | .  .  .  .  .  .  .  . |
/// 5 | .  .  .  .  .  .  .  . |
/// 4 | .  .  .  .  .  .  .  . |
/// 3 | .  .  .  .  .  .  .  . |
/// 2 | P  P  P  P  P  P  P  P |
/// 1 | R  N  B  Q  K  B  N  R |
///   +------------------------+
///     a  b  c  d  e  f  g  h
pub fn moves_basic_test() {
  let assert Ok(game) =
    load_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

  game.moves(game)
  |> list.map(game.move_to_san)
  |> list.sort(string.compare)
  |> should.equal([
    "Na3", "Nc3", "Nf3", "Nh3", "a3", "a4", "b3", "b4", "c3", "c4", "d3", "d4",
    "e3", "e4", "f3", "f4", "g3", "g4", "h3", "h4",
  ])
}

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

  game.moves(game)
  |> list.map(game.move_to_san)
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

  game.moves(game)
  |> list.map(game.move_to_san)
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

  game.moves(game)
  |> list.map(game.move_to_san)
  |> list.sort(string.compare)
  |> should.equal([
    "Kg1", "Kg2", "Kh2", "Qa4", "Qa7", "Qb4", "Qb6", "Qc4", "Qc5", "Qd1", "Qd2",
    "Qd3", "Qd5", "Qd6", "Qd7", "Qd8", "Qe3", "Qe4", "Qe5", "Qf2", "Qf4", "Qg1",
    "Qg4", "Qh4", "Qxf6", "c4",
  ])
}

/// a2: Can double jump and can't capture own pawn
/// b3: Can only single jump
/// d2: Can capture on either side, single or double jump
/// e2: Stuck because of pawn in front
///    +------------------------+
///  8 | .  .  .  .  .  .  .  k |
///  7 | .  .  .  .  .  .  .  . |
///  6 | .  .  .  .  .  .  .  . |
///  5 | .  .  .  .  .  .  .  . |
///  4 | .  .  .  .  .  .  .  . |
///  3 | .  P  p  .  p  .  .  . |
///  2 | P  .  .  P  P  .  .  . |
///  1 | .  .  .  .  .  .  .  K |
///    +------------------------+
///      a  b  c  d  e  f  g  h
pub fn moves_pawn_test() {
  let assert Ok(game) = load_fen("7k/8/8/8/8/1Pp1p3/P2PP3/7K w - - 0 1")

  game.moves(game)
  |> list.map(game.move_to_san)
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

  game.moves(game)
  |> list.map(game.move_to_san)
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

  game.moves(game)
  |> list.map(game.move_to_san)
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

  game.moves(game)
  |> list.map(game.move_to_san)
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

  game.moves(game)
  |> list.map(game.move_to_san)
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

  game.moves(game)
  |> list.map(game.move_to_san)
  |> list.sort(string.compare)
  |> should.equal(["Kh2"])
}

/// Can castle either side since all conditions are met.
///    +------------------------+
///  8 | r  .  .  .  k  .  .  r |
///  7 | p  p  p  p  p  p  p  p |
///  6 | .  .  .  .  .  .  .  . |
///  5 | .  .  .  .  .  .  .  . |
///  4 | .  .  .  .  .  .  .  . |
///  3 | .  .  .  .  .  .  .  . |
///  2 | P  P  P  P  P  P  P  P |
///  1 | R  .  .  .  K  .  .  R |
///    +------------------------+
///      a  b  c  d  e  f  g  h
pub fn moves_castle_test() {
  let assert Ok(game) =
    load_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1")
  game.moves(game)
  |> list.map(game.move_to_san)
  |> list.sort(string.compare)
  |> should.equal([
    "Kd1", "Kf1", "O-O", "O-O-O", "Rb1", "Rc1", "Rd1", "Rf1", "Rg1", "a3", "a4",
    "b3", "b4", "c3", "c4", "d3", "d4", "e3", "e4", "f3", "f4", "g3", "g4", "h3",
    "h4",
  ])
}

/// For whatever reason, white can't castle anymore (denoted in FEN)
///    +------------------------+
///  8 | r  .  .  .  k  .  .  r |
///  7 | p  p  p  p  p  p  p  p |
///  6 | .  .  .  .  .  .  .  . |
///  5 | .  .  .  .  .  .  .  . |
///  4 | .  .  .  .  .  .  .  . |
///  3 | .  .  .  .  .  .  .  . |
///  2 | P  P  P  P  P  P  P  P |
///  1 | R  .  .  .  K  .  .  R |
///    +------------------------+
///      a  b  c  d  e  f  g  h
pub fn moves_castle_ineligible_test() {
  let assert Ok(game) =
    load_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w kq - 0 1")
  game.moves(game)
  |> list.map(game.move_to_san)
  |> list.sort(string.compare)
  |> should.equal([
    "Kd1", "Kf1", "Rb1", "Rc1", "Rd1", "Rf1", "Rg1", "a3", "a4", "b3", "b4",
    "c3", "c4", "d3", "d4", "e3", "e4", "f3", "f4", "g3", "g4", "h3", "h4",
  ])
}

/// White has moved its rook and is no longer eligible for castling.
///    +------------------------+
///  8 | r  .  .  .  k  .  .  r |
///  7 | p  p  p  p  p  p  p  p |
///  6 | .  .  .  .  .  .  .  . |
///  5 | .  .  .  .  .  .  .  . |
///  4 | .  .  .  .  .  .  .  . |
///  3 | .  .  .  .  .  .  .  . |
///  2 | P  P  P  P  P  P  P  P |
///  1 | .  .  .  R  K  .  .  R |
///    +------------------------+
///      a  b  c  d  e  f  g  h
pub fn moves_castle_not_moved_test() {
  let assert Ok(game) =
    load_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/3RK2R w Kkq - 1 1")
  game.moves(game)
  |> list.map(game.move_to_san)
  |> list.sort(string.compare)
  |> should.equal([
    "Kf1", "O-O", "Ra1", "Rb1", "Rc1", "Rf1", "Rg1", "a3", "a4", "b3", "b4",
    "c3", "c4", "d3", "d4", "e3", "e4", "f3", "f4", "g3", "g4", "h3", "h4",
  ])
}

/// There's a piece in between the king and its rook
///    +------------------------+
///  8 | r  .  .  .  k  .  .  r |
///  7 | p  p  p  p  p  p  p  p |
///  6 | .  .  .  .  .  .  .  . |
///  5 | .  .  .  .  .  .  .  . |
///  4 | .  .  .  .  .  .  .  . |
///  3 | .  .  .  .  .  .  .  . |
///  2 | P  P  P  P  P  P  P  P |
///  1 | R  .  B  .  K  .  .  R |
///    +------------------------+
///      a  b  c  d  e  f  g  h
pub fn moves_castle_no_block_test() {
  let assert Ok(game) =
    load_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R1B1K2R w KQkq - 0 1")
  game.moves(game)
  |> list.map(game.move_to_san)
  |> list.sort(string.compare)
  |> should.equal([
    "Kd1", "Kf1", "O-O", "Rb1", "Rf1", "Rg1", "a3", "a4", "b3", "b4", "c3", "c4",
    "d3", "d4", "e3", "e4", "f3", "f4", "g3", "g4", "h3", "h4",
  ])
}

/// Black king in check and therefore cannot castle
///    +------------------------+
///  8 | r  .  .  .  k  .  .  r |
///  7 | .  .  .  .  .  .  .  . |
///  6 | .  .  .  .  .  .  B  . |
///  5 | .  .  .  .  .  .  .  . |
///  4 | .  .  .  .  .  .  .  . |
///  3 | .  .  .  .  .  .  .  . |
///  2 | .  .  .  .  .  .  .  . |
///  1 | .  .  .  .  K  .  .  . |
///    +------------------------+
///      a  b  c  d  e  f  g  h
pub fn moves_castle_no_check_test() {
  let assert Ok(game) = load_fen("r3k2r/8/6B1/8/8/8/8/4K3 b kq - 0 1")
  game.moves(game)
  |> list.map(game.move_to_san)
  |> list.sort(string.compare)
  |> should.equal(["Kd7", "Kd8", "Ke7", "Kf8"])
}

/// White cannot castle queenside because Black's queen controls c1.
/// White can castle kingside even though the h1-rook is under attack.
///    +------------------------+
///  8 | .  .  .  .  k  .  .  . |
///  7 | .  .  .  .  .  .  .  . |
///  6 | .  .  q  .  .  .  .  . |
///  5 | .  .  .  .  .  .  .  . |
///  4 | .  .  .  .  .  .  .  . |
///  3 | .  .  .  .  .  .  .  . |
///  2 | .  .  .  .  .  .  .  . |
///  1 | R  .  .  .  K  .  .  R |
///    +------------------------+
///      a  b  c  d  e  f  g  h
pub fn moves_castle_passthrough_test() {
  let assert Ok(game) = load_fen("4k3/8/2q5/8/8/8/8/R3K2R w KQ - 0 1")
  game.moves(game)
  |> list.map(game.move_to_san)
  |> list.sort(string.compare)
  |> should.equal([
    "Kd1", "Kd2", "Ke2", "Kf1", "Kf2", "O-O", "Ra2", "Ra3", "Ra4", "Ra5", "Ra6",
    "Ra7", "Ra8+", "Rb1", "Rc1", "Rd1", "Rf1", "Rg1", "Rh2", "Rh3", "Rh4", "Rh5",
    "Rh6", "Rh7", "Rh8+",
  ])
}

///   +------------------------+
/// 8 | .  n  b  q  k  b  n  r |
/// 7 | r  p  p  p  p  p  p  p |
/// 6 | .  .  .  .  .  .  .  . |
/// 5 | p  .  .  .  .  .  .  . |
/// 4 | .  .  .  .  .  .  .  . |
/// 3 | .  .  .  P  K  .  .  . |
/// 2 | P  P  P  .  P  P  P  P |
/// 1 | R  N  B  Q  .  B  N  R |
///   +------------------------+
///     a  b  c  d  e  f  g  h
pub fn moves_real_world_1_test() {
  let assert Ok(game) =
    load_fen("1nbqkbnr/rppppppp/8/p7/8/3PK3/PPP1PPPP/RNBQ1BNR w - - 0 1")
  game.moves(game)
  |> list.map(game.move_to_san)
  |> list.sort(string.compare)
  |> should.equal([
    "Bd2", "Kd2", "Kd4", "Ke4", "Kf3", "Kf4", "Na3", "Nc3", "Nd2", "Nf3", "Nh3",
    "Qd2", "Qe1", "a3", "a4", "b3", "b4", "c3", "c4", "d4", "f3", "f4", "g3",
    "g4", "h3", "h4",
  ])
}

///    +------------------------+
///  8 | .  n  b  q  k  b  n  r |
///  7 | r  p  p  p  p  p  p  p |
///  6 | .  .  .  .  .  .  .  . |
///  5 | p  .  .  P  .  .  .  . |
///  4 | .  .  P  .  P  .  .  . |
///  3 | .  .  .  .  .  .  .  . |
///  2 | P  P  .  .  .  P  P  P |
///  1 | R  N  B  Q  K  B  N  R |
///    +------------------------+
///      a  b  c  d  e  f  g  h
pub fn moves_real_world_2_test() {
  let assert Ok(game) =
    load_fen("1nbqkbnr/rppppppp/8/p2P4/2P1P3/8/PP3PPP/RNBQKBNR b KQk - 0 4")
  game.moves(game)
  |> list.map(game.move_to_san)
  |> list.sort(string.compare)
  |> should.equal([
    "Na6", "Nc6", "Nf6", "Nh6", "Ra6", "Ra8", "a4", "b5", "b6", "c5", "c6", "d6",
    "e5", "e6", "f5", "f6", "g5", "g6", "h5", "h6",
  ])
}

// END: move.moves tests

// BEGIN: move.apply tests

pub fn apply_basic_test() {
  let assert Ok(game) =
    load_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

  let assert Ok(move_e4) = game.move_from_san("e4", game)
  let assert Ok(game) = game.apply(game, move_e4)

  // TODO: Ideally, use game.to_fen for a more compact format
  game.board(game)
  |> should.equal(
    dict.from_list([
      #(square.H1, piece.Piece(player.White, piece.Rook)),
      #(square.H2, piece.Piece(player.White, piece.Pawn)),
      #(square.A1, piece.Piece(player.White, piece.Rook)),
      #(square.B1, piece.Piece(player.White, piece.Knight)),
      #(square.C1, piece.Piece(player.White, piece.Bishop)),
      #(square.D1, piece.Piece(player.White, piece.Queen)),
      #(square.E1, piece.Piece(player.White, piece.King)),
      #(square.F1, piece.Piece(player.White, piece.Bishop)),
      #(square.G1, piece.Piece(player.White, piece.Knight)),
      #(square.A2, piece.Piece(player.White, piece.Pawn)),
      #(square.B2, piece.Piece(player.White, piece.Pawn)),
      #(square.C2, piece.Piece(player.White, piece.Pawn)),
      #(square.D2, piece.Piece(player.White, piece.Pawn)),
      #(square.F2, piece.Piece(player.White, piece.Pawn)),
      #(square.G2, piece.Piece(player.White, piece.Pawn)),
      #(square.A8, piece.Piece(player.Black, piece.Rook)),
      #(square.B8, piece.Piece(player.Black, piece.Knight)),
      #(square.C8, piece.Piece(player.Black, piece.Bishop)),
      #(square.D8, piece.Piece(player.Black, piece.Queen)),
      #(square.E8, piece.Piece(player.Black, piece.King)),
      #(square.F8, piece.Piece(player.Black, piece.Bishop)),
      #(square.G8, piece.Piece(player.Black, piece.Knight)),
      #(square.H8, piece.Piece(player.Black, piece.Rook)),
      #(square.A7, piece.Piece(player.Black, piece.Pawn)),
      #(square.B7, piece.Piece(player.Black, piece.Pawn)),
      #(square.C7, piece.Piece(player.Black, piece.Pawn)),
      #(square.D7, piece.Piece(player.Black, piece.Pawn)),
      #(square.E7, piece.Piece(player.Black, piece.Pawn)),
      #(square.F7, piece.Piece(player.Black, piece.Pawn)),
      #(square.G7, piece.Piece(player.Black, piece.Pawn)),
      #(square.H7, piece.Piece(player.Black, piece.Pawn)),
      #(square.E4, piece.Piece(player.White, piece.Pawn)),
    ]),
  )
  game.turn(game) |> should.equal(player.Black)
}

/// White should revoke its castling availability after moving king
///    +------------------------+
///  8 | r  .  .  .  k  .  .  r |
///  7 | p  p  p  p  p  p  p  p |
///  6 | .  .  .  .  .  .  .  . |
///  5 | .  .  .  .  .  .  .  . |
///  4 | .  .  .  .  .  .  .  . |
///  3 | .  .  .  .  .  .  .  . |
///  2 | P  P  P  P  P  P  P  P |
///  1 | R  .  .  .  K  .  .  R |
///    +------------------------+
///      a  b  c  d  e  f  g  h
pub fn apply_castling_availability_move_king_test() {
  // Regular move
  let assert Ok(game) =
    load_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQ - 0 1")
  let assert Ok(move) = game.move_from_san("Kd1", game)
  let assert Ok(game) = game.apply(game, move)
  game.castling_availability(game) |> should.equal([])

  // Long castle
  let assert Ok(game) =
    load_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQ - 0 1")
  let assert Ok(move) = game.move_from_san("O-O-O", game)
  let assert Ok(game) = game.apply(game, move)
  game.castling_availability(game) |> should.equal([])

  // Short castle
  let assert Ok(game) =
    load_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQ - 0 1")
  let assert Ok(move) = game.move_from_san("O-O", game)
  let assert Ok(game) = game.apply(game, move)
  game.castling_availability(game) |> should.equal([])
}

/// White should revoke its castling availability after moving rook on each
/// side
///    +------------------------+
///  8 | r  .  .  .  k  .  .  r |
///  7 | p  p  p  p  p  p  p  p |
///  6 | .  .  .  .  .  .  .  . |
///  5 | .  .  .  .  .  .  .  . |
///  4 | .  .  .  .  .  .  .  . |
///  3 | .  .  .  .  .  .  .  . |
///  2 | P  P  P  P  P  P  P  P |
///  1 | R  .  .  .  K  .  .  R |
///    +------------------------+
///      a  b  c  d  e  f  g  h
pub fn apply_castling_availability_move_rook_test() {
  let assert Ok(game) =
    load_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQ - 0 1")

  let assert Ok(move) = game.move_from_san("Rb1", game)
  let assert Ok(game) = game.apply(game, move)
  game.castling_availability(game)
  |> should.equal([#(player.White, game.KingSide)])

  let assert Ok(game) =
    load_fen("r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQ - 0 1")
  let assert Ok(move) = game.move_from_san("Rg1", game)
  let assert Ok(game) = game.apply(game, move)
  game.castling_availability(game)
  |> should.equal([#(player.White, game.QueenSide)])
}

/// Black should revoke its castling availability after having its rook
/// captured on each side
///    +------------------------+
///  8 | r  .  .  .  k  .  .  r |
///  7 | .  p  p  p  .  p  p  . |
///  6 | .  .  .  .  .  .  .  . |
///  5 | .  .  .  .  .  .  .  . |
///  4 | .  .  .  .  .  .  .  . |
///  3 | .  .  .  .  .  .  .  . |
///  2 | .  P  P  P  P  P  P  . |
///  1 | R  .  .  .  K  .  .  R |
///    +------------------------+
///      a  b  c  d  e  f  g  h
pub fn apply_castling_availability_move_rook_capture_test() {
  let assert Ok(game) =
    load_fen("r3k2r/1ppp1pp1/8/8/8/8/1PPPPPP1/R3K2R w kq - 0 1")

  let assert Ok(move) = game.move_from_san("Rxa8+", game)
  let assert Ok(game) = game.apply(game, move)
  game.castling_availability(game)
  |> should.equal([#(player.Black, game.KingSide)])

  let assert Ok(game) =
    load_fen("r3k2r/1pppppp1/8/8/8/8/1PPPPPP1/R3K2R w KQ - 0 1")
  let assert Ok(move) = game.move_from_san("Rg1", game)
  let assert Ok(game) = game.apply(game, move)
  game.castling_availability(game)
  |> should.equal([#(player.White, game.QueenSide)])
}
// END: move.apply tests
