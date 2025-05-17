import chess/piece
import chess/square
import gleam/bool
import gleam/option.{type Option}
import gleam/result
import util/yielder

pub type Board(a) {
  Board(
    a8: a,
    b8: a,
    c8: a,
    d8: a,
    e8: a,
    f8: a,
    g8: a,
    h8: a,
    a7: a,
    b7: a,
    c7: a,
    d7: a,
    e7: a,
    f7: a,
    g7: a,
    h7: a,
    a6: a,
    b6: a,
    c6: a,
    d6: a,
    e6: a,
    f6: a,
    g6: a,
    h6: a,
    a5: a,
    b5: a,
    c5: a,
    d5: a,
    e5: a,
    f5: a,
    g5: a,
    h5: a,
    a4: a,
    b4: a,
    c4: a,
    d4: a,
    e4: a,
    f4: a,
    g4: a,
    h4: a,
    a3: a,
    b3: a,
    c3: a,
    d3: a,
    e3: a,
    f3: a,
    g3: a,
    h3: a,
    a2: a,
    b2: a,
    c2: a,
    d2: a,
    e2: a,
    f2: a,
    g2: a,
    h2: a,
    a1: a,
    b1: a,
    c1: a,
    d1: a,
    e1: a,
    f1: a,
    g1: a,
    h1: a,
  )
}

pub type PieceBoard =
  Board(Option(piece.Piece))

pub fn map(board: Board(a), with fun: fn(a) -> b) -> Board(b) {
  Board(
    a8: fun(board.a8),
    b8: fun(board.b8),
    c8: fun(board.c8),
    d8: fun(board.d8),
    e8: fun(board.e8),
    f8: fun(board.f8),
    g8: fun(board.g8),
    h8: fun(board.h8),
    a7: fun(board.a7),
    b7: fun(board.b7),
    c7: fun(board.c7),
    d7: fun(board.d7),
    e7: fun(board.e7),
    f7: fun(board.f7),
    g7: fun(board.g7),
    h7: fun(board.h7),
    a6: fun(board.a6),
    b6: fun(board.b6),
    c6: fun(board.c6),
    d6: fun(board.d6),
    e6: fun(board.e6),
    f6: fun(board.f6),
    g6: fun(board.g6),
    h6: fun(board.h6),
    a5: fun(board.a5),
    b5: fun(board.b5),
    c5: fun(board.c5),
    d5: fun(board.d5),
    e5: fun(board.e5),
    f5: fun(board.f5),
    g5: fun(board.g5),
    h5: fun(board.h5),
    a4: fun(board.a4),
    b4: fun(board.b4),
    c4: fun(board.c4),
    d4: fun(board.d4),
    e4: fun(board.e4),
    f4: fun(board.f4),
    g4: fun(board.g4),
    h4: fun(board.h4),
    a3: fun(board.a3),
    b3: fun(board.b3),
    c3: fun(board.c3),
    d3: fun(board.d3),
    e3: fun(board.e3),
    f3: fun(board.f3),
    g3: fun(board.g3),
    h3: fun(board.h3),
    a2: fun(board.a2),
    b2: fun(board.b2),
    c2: fun(board.c2),
    d2: fun(board.d2),
    e2: fun(board.e2),
    f2: fun(board.f2),
    g2: fun(board.g2),
    h2: fun(board.h2),
    a1: fun(board.a1),
    b1: fun(board.b1),
    c1: fun(board.c1),
    d1: fun(board.d1),
    e1: fun(board.e1),
    f1: fun(board.f1),
    g1: fun(board.g1),
    h1: fun(board.h1),
  )
}

pub fn square_map(
  board: Board(a),
  with fun: fn(a, square.Square) -> b,
) -> Board(b) {
  Board(
    a8: fun(board.a8, square.Square(0)),
    b8: fun(board.b8, square.Square(1)),
    c8: fun(board.c8, square.Square(2)),
    d8: fun(board.d8, square.Square(3)),
    e8: fun(board.e8, square.Square(4)),
    f8: fun(board.f8, square.Square(5)),
    g8: fun(board.g8, square.Square(6)),
    h8: fun(board.h8, square.Square(7)),
    a7: fun(board.a7, square.Square(16)),
    b7: fun(board.b7, square.Square(17)),
    c7: fun(board.c7, square.Square(18)),
    d7: fun(board.d7, square.Square(19)),
    e7: fun(board.e7, square.Square(20)),
    f7: fun(board.f7, square.Square(21)),
    g7: fun(board.g7, square.Square(22)),
    h7: fun(board.h7, square.Square(23)),
    a6: fun(board.a6, square.Square(32)),
    b6: fun(board.b6, square.Square(33)),
    c6: fun(board.c6, square.Square(34)),
    d6: fun(board.d6, square.Square(35)),
    e6: fun(board.e6, square.Square(36)),
    f6: fun(board.f6, square.Square(37)),
    g6: fun(board.g6, square.Square(38)),
    h6: fun(board.h6, square.Square(39)),
    a5: fun(board.a5, square.Square(48)),
    b5: fun(board.b5, square.Square(49)),
    c5: fun(board.c5, square.Square(50)),
    d5: fun(board.d5, square.Square(51)),
    e5: fun(board.e5, square.Square(52)),
    f5: fun(board.f5, square.Square(53)),
    g5: fun(board.g5, square.Square(54)),
    h5: fun(board.h5, square.Square(55)),
    a4: fun(board.a4, square.Square(64)),
    b4: fun(board.b4, square.Square(65)),
    c4: fun(board.c4, square.Square(66)),
    d4: fun(board.d4, square.Square(67)),
    e4: fun(board.e4, square.Square(68)),
    f4: fun(board.f4, square.Square(69)),
    g4: fun(board.g4, square.Square(70)),
    h4: fun(board.h4, square.Square(71)),
    a3: fun(board.a3, square.Square(80)),
    b3: fun(board.b3, square.Square(81)),
    c3: fun(board.c3, square.Square(82)),
    d3: fun(board.d3, square.Square(83)),
    e3: fun(board.e3, square.Square(84)),
    f3: fun(board.f3, square.Square(85)),
    g3: fun(board.g3, square.Square(86)),
    h3: fun(board.h3, square.Square(87)),
    a2: fun(board.a2, square.Square(96)),
    b2: fun(board.b2, square.Square(97)),
    c2: fun(board.c2, square.Square(98)),
    d2: fun(board.d2, square.Square(99)),
    e2: fun(board.e2, square.Square(100)),
    f2: fun(board.f2, square.Square(101)),
    g2: fun(board.g2, square.Square(102)),
    h2: fun(board.h2, square.Square(103)),
    a1: fun(board.a1, square.Square(112)),
    b1: fun(board.b1, square.Square(113)),
    c1: fun(board.c1, square.Square(114)),
    d1: fun(board.d1, square.Square(115)),
    e1: fun(board.e1, square.Square(116)),
    f1: fun(board.f1, square.Square(117)),
    g1: fun(board.g1, square.Square(118)),
    h1: fun(board.h1, square.Square(119)),
  )
}

pub fn square_ox88_map(board: Board(a), with fun: fn(a, Int) -> b) -> Board(b) {
  Board(
    a8: fun(board.a8, 0),
    b8: fun(board.b8, 1),
    c8: fun(board.c8, 2),
    d8: fun(board.d8, 3),
    e8: fun(board.e8, 4),
    f8: fun(board.f8, 5),
    g8: fun(board.g8, 6),
    h8: fun(board.h8, 7),
    a7: fun(board.a7, 16),
    b7: fun(board.b7, 17),
    c7: fun(board.c7, 18),
    d7: fun(board.d7, 19),
    e7: fun(board.e7, 20),
    f7: fun(board.f7, 21),
    g7: fun(board.g7, 22),
    h7: fun(board.h7, 23),
    a6: fun(board.a6, 32),
    b6: fun(board.b6, 33),
    c6: fun(board.c6, 34),
    d6: fun(board.d6, 35),
    e6: fun(board.e6, 36),
    f6: fun(board.f6, 37),
    g6: fun(board.g6, 38),
    h6: fun(board.h6, 39),
    a5: fun(board.a5, 48),
    b5: fun(board.b5, 49),
    c5: fun(board.c5, 50),
    d5: fun(board.d5, 51),
    e5: fun(board.e5, 52),
    f5: fun(board.f5, 53),
    g5: fun(board.g5, 54),
    h5: fun(board.h5, 55),
    a4: fun(board.a4, 64),
    b4: fun(board.b4, 65),
    c4: fun(board.c4, 66),
    d4: fun(board.d4, 67),
    e4: fun(board.e4, 68),
    f4: fun(board.f4, 69),
    g4: fun(board.g4, 70),
    h4: fun(board.h4, 71),
    a3: fun(board.a3, 80),
    b3: fun(board.b3, 81),
    c3: fun(board.c3, 82),
    d3: fun(board.d3, 83),
    e3: fun(board.e3, 84),
    f3: fun(board.f3, 85),
    g3: fun(board.g3, 86),
    h3: fun(board.h3, 87),
    a2: fun(board.a2, 96),
    b2: fun(board.b2, 97),
    c2: fun(board.c2, 98),
    d2: fun(board.d2, 99),
    e2: fun(board.e2, 100),
    f2: fun(board.f2, 101),
    g2: fun(board.g2, 102),
    h2: fun(board.h2, 103),
    a1: fun(board.a1, 112),
    b1: fun(board.b1, 113),
    c1: fun(board.c1, 114),
    d1: fun(board.d1, 115),
    e1: fun(board.e1, 116),
    f1: fun(board.f1, 117),
    g1: fun(board.g1, 118),
    h1: fun(board.h1, 119),
  )
}

/// Folds from top left to bottom right
///
pub fn fold(
  over board: Board(a),
  from initial: acc,
  with fun: fn(acc, a) -> acc,
) -> acc {
  let acc = initial
  let acc = fun(acc, board.a8)
  let acc = fun(acc, board.b8)
  let acc = fun(acc, board.c8)
  let acc = fun(acc, board.d8)
  let acc = fun(acc, board.e8)
  let acc = fun(acc, board.f8)
  let acc = fun(acc, board.g8)
  let acc = fun(acc, board.h8)
  let acc = fun(acc, board.a7)
  let acc = fun(acc, board.b7)
  let acc = fun(acc, board.c7)
  let acc = fun(acc, board.d7)
  let acc = fun(acc, board.e7)
  let acc = fun(acc, board.f7)
  let acc = fun(acc, board.g7)
  let acc = fun(acc, board.h7)
  let acc = fun(acc, board.a6)
  let acc = fun(acc, board.b6)
  let acc = fun(acc, board.c6)
  let acc = fun(acc, board.d6)
  let acc = fun(acc, board.e6)
  let acc = fun(acc, board.f6)
  let acc = fun(acc, board.g6)
  let acc = fun(acc, board.h6)
  let acc = fun(acc, board.a5)
  let acc = fun(acc, board.b5)
  let acc = fun(acc, board.c5)
  let acc = fun(acc, board.d5)
  let acc = fun(acc, board.e5)
  let acc = fun(acc, board.f5)
  let acc = fun(acc, board.g5)
  let acc = fun(acc, board.h5)
  let acc = fun(acc, board.a4)
  let acc = fun(acc, board.b4)
  let acc = fun(acc, board.c4)
  let acc = fun(acc, board.d4)
  let acc = fun(acc, board.e4)
  let acc = fun(acc, board.f4)
  let acc = fun(acc, board.g4)
  let acc = fun(acc, board.h4)
  let acc = fun(acc, board.a3)
  let acc = fun(acc, board.b3)
  let acc = fun(acc, board.c3)
  let acc = fun(acc, board.d3)
  let acc = fun(acc, board.e3)
  let acc = fun(acc, board.f3)
  let acc = fun(acc, board.g3)
  let acc = fun(acc, board.h3)
  let acc = fun(acc, board.a2)
  let acc = fun(acc, board.b2)
  let acc = fun(acc, board.c2)
  let acc = fun(acc, board.d2)
  let acc = fun(acc, board.e2)
  let acc = fun(acc, board.f2)
  let acc = fun(acc, board.g2)
  let acc = fun(acc, board.h2)
  let acc = fun(acc, board.a1)
  let acc = fun(acc, board.b1)
  let acc = fun(acc, board.c1)
  let acc = fun(acc, board.d1)
  let acc = fun(acc, board.e1)
  let acc = fun(acc, board.f1)
  let acc = fun(acc, board.g1)
  let acc = fun(acc, board.h1)
  acc
}

pub fn square_fold(
  over board: Board(a),
  from initial: acc,
  with fun: fn(acc, a, square.Square) -> acc,
) -> acc {
  let acc = initial
  let acc = fun(acc, board.a8, square.Square(0))
  let acc = fun(acc, board.b8, square.Square(1))
  let acc = fun(acc, board.c8, square.Square(2))
  let acc = fun(acc, board.d8, square.Square(3))
  let acc = fun(acc, board.e8, square.Square(4))
  let acc = fun(acc, board.f8, square.Square(5))
  let acc = fun(acc, board.g8, square.Square(6))
  let acc = fun(acc, board.h8, square.Square(7))
  let acc = fun(acc, board.a7, square.Square(16))
  let acc = fun(acc, board.b7, square.Square(17))
  let acc = fun(acc, board.c7, square.Square(18))
  let acc = fun(acc, board.d7, square.Square(19))
  let acc = fun(acc, board.e7, square.Square(20))
  let acc = fun(acc, board.f7, square.Square(21))
  let acc = fun(acc, board.g7, square.Square(22))
  let acc = fun(acc, board.h7, square.Square(23))
  let acc = fun(acc, board.a6, square.Square(32))
  let acc = fun(acc, board.b6, square.Square(33))
  let acc = fun(acc, board.c6, square.Square(34))
  let acc = fun(acc, board.d6, square.Square(35))
  let acc = fun(acc, board.e6, square.Square(36))
  let acc = fun(acc, board.f6, square.Square(37))
  let acc = fun(acc, board.g6, square.Square(38))
  let acc = fun(acc, board.h6, square.Square(39))
  let acc = fun(acc, board.a5, square.Square(48))
  let acc = fun(acc, board.b5, square.Square(49))
  let acc = fun(acc, board.c5, square.Square(50))
  let acc = fun(acc, board.d5, square.Square(51))
  let acc = fun(acc, board.e5, square.Square(52))
  let acc = fun(acc, board.f5, square.Square(53))
  let acc = fun(acc, board.g5, square.Square(54))
  let acc = fun(acc, board.h5, square.Square(55))
  let acc = fun(acc, board.a4, square.Square(64))
  let acc = fun(acc, board.b4, square.Square(65))
  let acc = fun(acc, board.c4, square.Square(66))
  let acc = fun(acc, board.d4, square.Square(67))
  let acc = fun(acc, board.e4, square.Square(68))
  let acc = fun(acc, board.f4, square.Square(69))
  let acc = fun(acc, board.g4, square.Square(70))
  let acc = fun(acc, board.h4, square.Square(71))
  let acc = fun(acc, board.a3, square.Square(80))
  let acc = fun(acc, board.b3, square.Square(81))
  let acc = fun(acc, board.c3, square.Square(82))
  let acc = fun(acc, board.d3, square.Square(83))
  let acc = fun(acc, board.e3, square.Square(84))
  let acc = fun(acc, board.f3, square.Square(85))
  let acc = fun(acc, board.g3, square.Square(86))
  let acc = fun(acc, board.h3, square.Square(87))
  let acc = fun(acc, board.a2, square.Square(96))
  let acc = fun(acc, board.b2, square.Square(97))
  let acc = fun(acc, board.c2, square.Square(98))
  let acc = fun(acc, board.d2, square.Square(99))
  let acc = fun(acc, board.e2, square.Square(100))
  let acc = fun(acc, board.f2, square.Square(101))
  let acc = fun(acc, board.g2, square.Square(102))
  let acc = fun(acc, board.h2, square.Square(103))
  let acc = fun(acc, board.a1, square.Square(112))
  let acc = fun(acc, board.b1, square.Square(113))
  let acc = fun(acc, board.c1, square.Square(114))
  let acc = fun(acc, board.d1, square.Square(115))
  let acc = fun(acc, board.e1, square.Square(116))
  let acc = fun(acc, board.f1, square.Square(117))
  let acc = fun(acc, board.g1, square.Square(118))
  let acc = fun(acc, board.h1, square.Square(119))
  acc
}

pub fn square_ox88_fold(
  over board: Board(a),
  from initial: acc,
  with fun: fn(acc, a, Int) -> acc,
) -> acc {
  let acc = initial
  let acc = fun(acc, board.a8, 0)
  let acc = fun(acc, board.b8, 1)
  let acc = fun(acc, board.c8, 2)
  let acc = fun(acc, board.d8, 3)
  let acc = fun(acc, board.e8, 4)
  let acc = fun(acc, board.f8, 5)
  let acc = fun(acc, board.g8, 6)
  let acc = fun(acc, board.h8, 7)
  let acc = fun(acc, board.a7, 16)
  let acc = fun(acc, board.b7, 17)
  let acc = fun(acc, board.c7, 18)
  let acc = fun(acc, board.d7, 19)
  let acc = fun(acc, board.e7, 20)
  let acc = fun(acc, board.f7, 21)
  let acc = fun(acc, board.g7, 22)
  let acc = fun(acc, board.h7, 23)
  let acc = fun(acc, board.a6, 32)
  let acc = fun(acc, board.b6, 33)
  let acc = fun(acc, board.c6, 34)
  let acc = fun(acc, board.d6, 35)
  let acc = fun(acc, board.e6, 36)
  let acc = fun(acc, board.f6, 37)
  let acc = fun(acc, board.g6, 38)
  let acc = fun(acc, board.h6, 39)
  let acc = fun(acc, board.a5, 48)
  let acc = fun(acc, board.b5, 49)
  let acc = fun(acc, board.c5, 50)
  let acc = fun(acc, board.d5, 51)
  let acc = fun(acc, board.e5, 52)
  let acc = fun(acc, board.f5, 53)
  let acc = fun(acc, board.g5, 54)
  let acc = fun(acc, board.h5, 55)
  let acc = fun(acc, board.a4, 64)
  let acc = fun(acc, board.b4, 65)
  let acc = fun(acc, board.c4, 66)
  let acc = fun(acc, board.d4, 67)
  let acc = fun(acc, board.e4, 68)
  let acc = fun(acc, board.f4, 69)
  let acc = fun(acc, board.g4, 70)
  let acc = fun(acc, board.h4, 71)
  let acc = fun(acc, board.a3, 80)
  let acc = fun(acc, board.b3, 81)
  let acc = fun(acc, board.c3, 82)
  let acc = fun(acc, board.d3, 83)
  let acc = fun(acc, board.e3, 84)
  let acc = fun(acc, board.f3, 85)
  let acc = fun(acc, board.g3, 86)
  let acc = fun(acc, board.h3, 87)
  let acc = fun(acc, board.a2, 96)
  let acc = fun(acc, board.b2, 97)
  let acc = fun(acc, board.c2, 98)
  let acc = fun(acc, board.d2, 99)
  let acc = fun(acc, board.e2, 100)
  let acc = fun(acc, board.f2, 101)
  let acc = fun(acc, board.g2, 102)
  let acc = fun(acc, board.h2, 103)
  let acc = fun(acc, board.a1, 112)
  let acc = fun(acc, board.b1, 113)
  let acc = fun(acc, board.c1, 114)
  let acc = fun(acc, board.d1, 115)
  let acc = fun(acc, board.e1, 116)
  let acc = fun(acc, board.f1, 117)
  let acc = fun(acc, board.g1, 118)
  let acc = fun(acc, board.h1, 119)
  acc
}

pub fn find(in board: Board(a), one_that is_desired: fn(a) -> Bool) {
  use <- bool.guard(is_desired(board.a8), Ok(board.a8))
  use <- bool.guard(is_desired(board.b8), Ok(board.b8))
  use <- bool.guard(is_desired(board.c8), Ok(board.c8))
  use <- bool.guard(is_desired(board.d8), Ok(board.d8))
  use <- bool.guard(is_desired(board.e8), Ok(board.e8))
  use <- bool.guard(is_desired(board.f8), Ok(board.f8))
  use <- bool.guard(is_desired(board.g8), Ok(board.g8))
  use <- bool.guard(is_desired(board.h8), Ok(board.h8))
  use <- bool.guard(is_desired(board.a7), Ok(board.a7))
  use <- bool.guard(is_desired(board.b7), Ok(board.b7))
  use <- bool.guard(is_desired(board.c7), Ok(board.c7))
  use <- bool.guard(is_desired(board.d7), Ok(board.d7))
  use <- bool.guard(is_desired(board.e7), Ok(board.e7))
  use <- bool.guard(is_desired(board.f7), Ok(board.f7))
  use <- bool.guard(is_desired(board.g7), Ok(board.g7))
  use <- bool.guard(is_desired(board.h7), Ok(board.h7))
  use <- bool.guard(is_desired(board.a6), Ok(board.a6))
  use <- bool.guard(is_desired(board.b6), Ok(board.b6))
  use <- bool.guard(is_desired(board.c6), Ok(board.c6))
  use <- bool.guard(is_desired(board.d6), Ok(board.d6))
  use <- bool.guard(is_desired(board.e6), Ok(board.e6))
  use <- bool.guard(is_desired(board.f6), Ok(board.f6))
  use <- bool.guard(is_desired(board.g6), Ok(board.g6))
  use <- bool.guard(is_desired(board.h6), Ok(board.h6))
  use <- bool.guard(is_desired(board.a5), Ok(board.a5))
  use <- bool.guard(is_desired(board.b5), Ok(board.b5))
  use <- bool.guard(is_desired(board.c5), Ok(board.c5))
  use <- bool.guard(is_desired(board.d5), Ok(board.d5))
  use <- bool.guard(is_desired(board.e5), Ok(board.e5))
  use <- bool.guard(is_desired(board.f5), Ok(board.f5))
  use <- bool.guard(is_desired(board.g5), Ok(board.g5))
  use <- bool.guard(is_desired(board.h5), Ok(board.h5))
  use <- bool.guard(is_desired(board.a4), Ok(board.a4))
  use <- bool.guard(is_desired(board.b4), Ok(board.b4))
  use <- bool.guard(is_desired(board.c4), Ok(board.c4))
  use <- bool.guard(is_desired(board.d4), Ok(board.d4))
  use <- bool.guard(is_desired(board.e4), Ok(board.e4))
  use <- bool.guard(is_desired(board.f4), Ok(board.f4))
  use <- bool.guard(is_desired(board.g4), Ok(board.g4))
  use <- bool.guard(is_desired(board.h4), Ok(board.h4))
  use <- bool.guard(is_desired(board.a3), Ok(board.a3))
  use <- bool.guard(is_desired(board.b3), Ok(board.b3))
  use <- bool.guard(is_desired(board.c3), Ok(board.c3))
  use <- bool.guard(is_desired(board.d3), Ok(board.d3))
  use <- bool.guard(is_desired(board.e3), Ok(board.e3))
  use <- bool.guard(is_desired(board.f3), Ok(board.f3))
  use <- bool.guard(is_desired(board.g3), Ok(board.g3))
  use <- bool.guard(is_desired(board.h3), Ok(board.h3))
  use <- bool.guard(is_desired(board.a2), Ok(board.a2))
  use <- bool.guard(is_desired(board.b2), Ok(board.b2))
  use <- bool.guard(is_desired(board.c2), Ok(board.c2))
  use <- bool.guard(is_desired(board.d2), Ok(board.d2))
  use <- bool.guard(is_desired(board.e2), Ok(board.e2))
  use <- bool.guard(is_desired(board.f2), Ok(board.f2))
  use <- bool.guard(is_desired(board.g2), Ok(board.g2))
  use <- bool.guard(is_desired(board.h2), Ok(board.h2))
  use <- bool.guard(is_desired(board.a1), Ok(board.a1))
  use <- bool.guard(is_desired(board.b1), Ok(board.b1))
  use <- bool.guard(is_desired(board.c1), Ok(board.c1))
  use <- bool.guard(is_desired(board.d1), Ok(board.d1))
  use <- bool.guard(is_desired(board.e1), Ok(board.e1))
  use <- bool.guard(is_desired(board.f1), Ok(board.f1))
  use <- bool.guard(is_desired(board.g1), Ok(board.g1))
  use <- bool.guard(is_desired(board.h1), Ok(board.h1))
  Error(Nil)
}

pub fn find_map(in board: Board(a), with fun: fn(a) -> Result(b, c)) {
  fun(board.a8)
  |> result.or(fun(board.b8))
  |> result.or(fun(board.c8))
  |> result.or(fun(board.d8))
  |> result.or(fun(board.e8))
  |> result.or(fun(board.f8))
  |> result.or(fun(board.g8))
  |> result.or(fun(board.h8))
  |> result.or(fun(board.a7))
  |> result.or(fun(board.b7))
  |> result.or(fun(board.c7))
  |> result.or(fun(board.d7))
  |> result.or(fun(board.e7))
  |> result.or(fun(board.f7))
  |> result.or(fun(board.g7))
  |> result.or(fun(board.h7))
  |> result.or(fun(board.a6))
  |> result.or(fun(board.b6))
  |> result.or(fun(board.c6))
  |> result.or(fun(board.d6))
  |> result.or(fun(board.e6))
  |> result.or(fun(board.f6))
  |> result.or(fun(board.g6))
  |> result.or(fun(board.h6))
  |> result.or(fun(board.a5))
  |> result.or(fun(board.b5))
  |> result.or(fun(board.c5))
  |> result.or(fun(board.d5))
  |> result.or(fun(board.e5))
  |> result.or(fun(board.f5))
  |> result.or(fun(board.g5))
  |> result.or(fun(board.h5))
  |> result.or(fun(board.a4))
  |> result.or(fun(board.b4))
  |> result.or(fun(board.c4))
  |> result.or(fun(board.d4))
  |> result.or(fun(board.e4))
  |> result.or(fun(board.f4))
  |> result.or(fun(board.g4))
  |> result.or(fun(board.h4))
  |> result.or(fun(board.a3))
  |> result.or(fun(board.b3))
  |> result.or(fun(board.c3))
  |> result.or(fun(board.d3))
  |> result.or(fun(board.e3))
  |> result.or(fun(board.f3))
  |> result.or(fun(board.g3))
  |> result.or(fun(board.h3))
  |> result.or(fun(board.a2))
  |> result.or(fun(board.b2))
  |> result.or(fun(board.c2))
  |> result.or(fun(board.d2))
  |> result.or(fun(board.e2))
  |> result.or(fun(board.f2))
  |> result.or(fun(board.g2))
  |> result.or(fun(board.h2))
  |> result.or(fun(board.a1))
  |> result.or(fun(board.b1))
  |> result.or(fun(board.c1))
  |> result.or(fun(board.d1))
  |> result.or(fun(board.e1))
  |> result.or(fun(board.f1))
  |> result.or(fun(board.g1))
  |> result.or(fun(board.h1))
}

pub fn square_find_map(
  in board: Board(a),
  with fun: fn(a, square.Square) -> Result(b, c),
) {
  fun(board.a8, square.Square(0))
  |> result.or(fun(board.b8, square.Square(1)))
  |> result.or(fun(board.c8, square.Square(2)))
  |> result.or(fun(board.d8, square.Square(3)))
  |> result.or(fun(board.e8, square.Square(4)))
  |> result.or(fun(board.f8, square.Square(5)))
  |> result.or(fun(board.g8, square.Square(6)))
  |> result.or(fun(board.h8, square.Square(7)))
  |> result.or(fun(board.a7, square.Square(16)))
  |> result.or(fun(board.b7, square.Square(17)))
  |> result.or(fun(board.c7, square.Square(18)))
  |> result.or(fun(board.d7, square.Square(19)))
  |> result.or(fun(board.e7, square.Square(20)))
  |> result.or(fun(board.f7, square.Square(21)))
  |> result.or(fun(board.g7, square.Square(22)))
  |> result.or(fun(board.h7, square.Square(23)))
  |> result.or(fun(board.a6, square.Square(32)))
  |> result.or(fun(board.b6, square.Square(33)))
  |> result.or(fun(board.c6, square.Square(34)))
  |> result.or(fun(board.d6, square.Square(35)))
  |> result.or(fun(board.e6, square.Square(36)))
  |> result.or(fun(board.f6, square.Square(37)))
  |> result.or(fun(board.g6, square.Square(38)))
  |> result.or(fun(board.h6, square.Square(39)))
  |> result.or(fun(board.a5, square.Square(48)))
  |> result.or(fun(board.b5, square.Square(49)))
  |> result.or(fun(board.c5, square.Square(50)))
  |> result.or(fun(board.d5, square.Square(51)))
  |> result.or(fun(board.e5, square.Square(52)))
  |> result.or(fun(board.f5, square.Square(53)))
  |> result.or(fun(board.g5, square.Square(54)))
  |> result.or(fun(board.h5, square.Square(55)))
  |> result.or(fun(board.a4, square.Square(64)))
  |> result.or(fun(board.b4, square.Square(65)))
  |> result.or(fun(board.c4, square.Square(66)))
  |> result.or(fun(board.d4, square.Square(67)))
  |> result.or(fun(board.e4, square.Square(68)))
  |> result.or(fun(board.f4, square.Square(69)))
  |> result.or(fun(board.g4, square.Square(70)))
  |> result.or(fun(board.h4, square.Square(71)))
  |> result.or(fun(board.a3, square.Square(80)))
  |> result.or(fun(board.b3, square.Square(81)))
  |> result.or(fun(board.c3, square.Square(82)))
  |> result.or(fun(board.d3, square.Square(83)))
  |> result.or(fun(board.e3, square.Square(84)))
  |> result.or(fun(board.f3, square.Square(85)))
  |> result.or(fun(board.g3, square.Square(86)))
  |> result.or(fun(board.h3, square.Square(87)))
  |> result.or(fun(board.a2, square.Square(96)))
  |> result.or(fun(board.b2, square.Square(97)))
  |> result.or(fun(board.c2, square.Square(98)))
  |> result.or(fun(board.d2, square.Square(99)))
  |> result.or(fun(board.e2, square.Square(100)))
  |> result.or(fun(board.f2, square.Square(101)))
  |> result.or(fun(board.g2, square.Square(102)))
  |> result.or(fun(board.h2, square.Square(103)))
  |> result.or(fun(board.a1, square.Square(112)))
  |> result.or(fun(board.b1, square.Square(113)))
  |> result.or(fun(board.c1, square.Square(114)))
  |> result.or(fun(board.d1, square.Square(115)))
  |> result.or(fun(board.e1, square.Square(116)))
  |> result.or(fun(board.f1, square.Square(117)))
  |> result.or(fun(board.g1, square.Square(118)))
  |> result.or(fun(board.h1, square.Square(119)))
}

pub fn square_ox88_find_map(
  in board: Board(a),
  with fun: fn(a, Int) -> Result(b, c),
) {
  fun(board.a8, 0)
  |> result.or(fun(board.b8, 1))
  |> result.or(fun(board.c8, 2))
  |> result.or(fun(board.d8, 3))
  |> result.or(fun(board.e8, 4))
  |> result.or(fun(board.f8, 5))
  |> result.or(fun(board.g8, 6))
  |> result.or(fun(board.h8, 7))
  |> result.or(fun(board.a7, 16))
  |> result.or(fun(board.b7, 17))
  |> result.or(fun(board.c7, 18))
  |> result.or(fun(board.d7, 19))
  |> result.or(fun(board.e7, 20))
  |> result.or(fun(board.f7, 21))
  |> result.or(fun(board.g7, 22))
  |> result.or(fun(board.h7, 23))
  |> result.or(fun(board.a6, 32))
  |> result.or(fun(board.b6, 33))
  |> result.or(fun(board.c6, 34))
  |> result.or(fun(board.d6, 35))
  |> result.or(fun(board.e6, 36))
  |> result.or(fun(board.f6, 37))
  |> result.or(fun(board.g6, 38))
  |> result.or(fun(board.h6, 39))
  |> result.or(fun(board.a5, 48))
  |> result.or(fun(board.b5, 49))
  |> result.or(fun(board.c5, 50))
  |> result.or(fun(board.d5, 51))
  |> result.or(fun(board.e5, 52))
  |> result.or(fun(board.f5, 53))
  |> result.or(fun(board.g5, 54))
  |> result.or(fun(board.h5, 55))
  |> result.or(fun(board.a4, 64))
  |> result.or(fun(board.b4, 65))
  |> result.or(fun(board.c4, 66))
  |> result.or(fun(board.d4, 67))
  |> result.or(fun(board.e4, 68))
  |> result.or(fun(board.f4, 69))
  |> result.or(fun(board.g4, 70))
  |> result.or(fun(board.h4, 71))
  |> result.or(fun(board.a3, 80))
  |> result.or(fun(board.b3, 81))
  |> result.or(fun(board.c3, 82))
  |> result.or(fun(board.d3, 83))
  |> result.or(fun(board.e3, 84))
  |> result.or(fun(board.f3, 85))
  |> result.or(fun(board.g3, 86))
  |> result.or(fun(board.h3, 87))
  |> result.or(fun(board.a2, 96))
  |> result.or(fun(board.b2, 97))
  |> result.or(fun(board.c2, 98))
  |> result.or(fun(board.d2, 99))
  |> result.or(fun(board.e2, 100))
  |> result.or(fun(board.f2, 101))
  |> result.or(fun(board.g2, 102))
  |> result.or(fun(board.h2, 103))
  |> result.or(fun(board.a1, 112))
  |> result.or(fun(board.b1, 113))
  |> result.or(fun(board.c1, 114))
  |> result.or(fun(board.d1, 115))
  |> result.or(fun(board.e1, 116))
  |> result.or(fun(board.f1, 117))
  |> result.or(fun(board.g1, 118))
  |> result.or(fun(board.h1, 119))
}

pub fn any(in board: Board(a), satisfying predicate: fn(a) -> Bool) {
  use <- bool.guard(predicate(board.a8), True)
  use <- bool.guard(predicate(board.b8), True)
  use <- bool.guard(predicate(board.c8), True)
  use <- bool.guard(predicate(board.d8), True)
  use <- bool.guard(predicate(board.e8), True)
  use <- bool.guard(predicate(board.f8), True)
  use <- bool.guard(predicate(board.g8), True)
  use <- bool.guard(predicate(board.h8), True)
  use <- bool.guard(predicate(board.a7), True)
  use <- bool.guard(predicate(board.b7), True)
  use <- bool.guard(predicate(board.c7), True)
  use <- bool.guard(predicate(board.d7), True)
  use <- bool.guard(predicate(board.e7), True)
  use <- bool.guard(predicate(board.f7), True)
  use <- bool.guard(predicate(board.g7), True)
  use <- bool.guard(predicate(board.h7), True)
  use <- bool.guard(predicate(board.a6), True)
  use <- bool.guard(predicate(board.b6), True)
  use <- bool.guard(predicate(board.c6), True)
  use <- bool.guard(predicate(board.d6), True)
  use <- bool.guard(predicate(board.e6), True)
  use <- bool.guard(predicate(board.f6), True)
  use <- bool.guard(predicate(board.g6), True)
  use <- bool.guard(predicate(board.h6), True)
  use <- bool.guard(predicate(board.a5), True)
  use <- bool.guard(predicate(board.b5), True)
  use <- bool.guard(predicate(board.c5), True)
  use <- bool.guard(predicate(board.d5), True)
  use <- bool.guard(predicate(board.e5), True)
  use <- bool.guard(predicate(board.f5), True)
  use <- bool.guard(predicate(board.g5), True)
  use <- bool.guard(predicate(board.h5), True)
  use <- bool.guard(predicate(board.a4), True)
  use <- bool.guard(predicate(board.b4), True)
  use <- bool.guard(predicate(board.c4), True)
  use <- bool.guard(predicate(board.d4), True)
  use <- bool.guard(predicate(board.e4), True)
  use <- bool.guard(predicate(board.f4), True)
  use <- bool.guard(predicate(board.g4), True)
  use <- bool.guard(predicate(board.h4), True)
  use <- bool.guard(predicate(board.a3), True)
  use <- bool.guard(predicate(board.b3), True)
  use <- bool.guard(predicate(board.c3), True)
  use <- bool.guard(predicate(board.d3), True)
  use <- bool.guard(predicate(board.e3), True)
  use <- bool.guard(predicate(board.f3), True)
  use <- bool.guard(predicate(board.g3), True)
  use <- bool.guard(predicate(board.h3), True)
  use <- bool.guard(predicate(board.a2), True)
  use <- bool.guard(predicate(board.b2), True)
  use <- bool.guard(predicate(board.c2), True)
  use <- bool.guard(predicate(board.d2), True)
  use <- bool.guard(predicate(board.e2), True)
  use <- bool.guard(predicate(board.f2), True)
  use <- bool.guard(predicate(board.g2), True)
  use <- bool.guard(predicate(board.h2), True)
  use <- bool.guard(predicate(board.a1), True)
  use <- bool.guard(predicate(board.b1), True)
  use <- bool.guard(predicate(board.c1), True)
  use <- bool.guard(predicate(board.d1), True)
  use <- bool.guard(predicate(board.e1), True)
  use <- bool.guard(predicate(board.f1), True)
  use <- bool.guard(predicate(board.g1), True)
  use <- bool.guard(predicate(board.h1), True)
  False
}

pub fn filter(board: Board(a), keeping predicate: fn(a) -> Bool) {
  let acc = yielder.empty()
  let acc = case predicate(board.a8) {
    True -> yielder.prepend(acc, board.a8)
    False -> acc
  }
  let acc = case predicate(board.b8) {
    True -> yielder.prepend(acc, board.b8)
    False -> acc
  }
  let acc = case predicate(board.c8) {
    True -> yielder.prepend(acc, board.c8)
    False -> acc
  }
  let acc = case predicate(board.d8) {
    True -> yielder.prepend(acc, board.d8)
    False -> acc
  }
  let acc = case predicate(board.e8) {
    True -> yielder.prepend(acc, board.e8)
    False -> acc
  }
  let acc = case predicate(board.f8) {
    True -> yielder.prepend(acc, board.f8)
    False -> acc
  }
  let acc = case predicate(board.g8) {
    True -> yielder.prepend(acc, board.g8)
    False -> acc
  }
  let acc = case predicate(board.h8) {
    True -> yielder.prepend(acc, board.h8)
    False -> acc
  }
  let acc = case predicate(board.a7) {
    True -> yielder.prepend(acc, board.a7)
    False -> acc
  }
  let acc = case predicate(board.b7) {
    True -> yielder.prepend(acc, board.b7)
    False -> acc
  }
  let acc = case predicate(board.c7) {
    True -> yielder.prepend(acc, board.c7)
    False -> acc
  }
  let acc = case predicate(board.d7) {
    True -> yielder.prepend(acc, board.d7)
    False -> acc
  }
  let acc = case predicate(board.e7) {
    True -> yielder.prepend(acc, board.e7)
    False -> acc
  }
  let acc = case predicate(board.f7) {
    True -> yielder.prepend(acc, board.f7)
    False -> acc
  }
  let acc = case predicate(board.g7) {
    True -> yielder.prepend(acc, board.g7)
    False -> acc
  }
  let acc = case predicate(board.h7) {
    True -> yielder.prepend(acc, board.h7)
    False -> acc
  }
  let acc = case predicate(board.a6) {
    True -> yielder.prepend(acc, board.a6)
    False -> acc
  }
  let acc = case predicate(board.b6) {
    True -> yielder.prepend(acc, board.b6)
    False -> acc
  }
  let acc = case predicate(board.c6) {
    True -> yielder.prepend(acc, board.c6)
    False -> acc
  }
  let acc = case predicate(board.d6) {
    True -> yielder.prepend(acc, board.d6)
    False -> acc
  }
  let acc = case predicate(board.e6) {
    True -> yielder.prepend(acc, board.e6)
    False -> acc
  }
  let acc = case predicate(board.f6) {
    True -> yielder.prepend(acc, board.f6)
    False -> acc
  }
  let acc = case predicate(board.g6) {
    True -> yielder.prepend(acc, board.g6)
    False -> acc
  }
  let acc = case predicate(board.h6) {
    True -> yielder.prepend(acc, board.h6)
    False -> acc
  }
  let acc = case predicate(board.a5) {
    True -> yielder.prepend(acc, board.a5)
    False -> acc
  }
  let acc = case predicate(board.b5) {
    True -> yielder.prepend(acc, board.b5)
    False -> acc
  }
  let acc = case predicate(board.c5) {
    True -> yielder.prepend(acc, board.c5)
    False -> acc
  }
  let acc = case predicate(board.d5) {
    True -> yielder.prepend(acc, board.d5)
    False -> acc
  }
  let acc = case predicate(board.e5) {
    True -> yielder.prepend(acc, board.e5)
    False -> acc
  }
  let acc = case predicate(board.f5) {
    True -> yielder.prepend(acc, board.f5)
    False -> acc
  }
  let acc = case predicate(board.g5) {
    True -> yielder.prepend(acc, board.g5)
    False -> acc
  }
  let acc = case predicate(board.h5) {
    True -> yielder.prepend(acc, board.h5)
    False -> acc
  }
  let acc = case predicate(board.a4) {
    True -> yielder.prepend(acc, board.a4)
    False -> acc
  }
  let acc = case predicate(board.b4) {
    True -> yielder.prepend(acc, board.b4)
    False -> acc
  }
  let acc = case predicate(board.c4) {
    True -> yielder.prepend(acc, board.c4)
    False -> acc
  }
  let acc = case predicate(board.d4) {
    True -> yielder.prepend(acc, board.d4)
    False -> acc
  }
  let acc = case predicate(board.e4) {
    True -> yielder.prepend(acc, board.e4)
    False -> acc
  }
  let acc = case predicate(board.f4) {
    True -> yielder.prepend(acc, board.f4)
    False -> acc
  }
  let acc = case predicate(board.g4) {
    True -> yielder.prepend(acc, board.g4)
    False -> acc
  }
  let acc = case predicate(board.h4) {
    True -> yielder.prepend(acc, board.h4)
    False -> acc
  }
  let acc = case predicate(board.a3) {
    True -> yielder.prepend(acc, board.a3)
    False -> acc
  }
  let acc = case predicate(board.b3) {
    True -> yielder.prepend(acc, board.b3)
    False -> acc
  }
  let acc = case predicate(board.c3) {
    True -> yielder.prepend(acc, board.c3)
    False -> acc
  }
  let acc = case predicate(board.d3) {
    True -> yielder.prepend(acc, board.d3)
    False -> acc
  }
  let acc = case predicate(board.e3) {
    True -> yielder.prepend(acc, board.e3)
    False -> acc
  }
  let acc = case predicate(board.f3) {
    True -> yielder.prepend(acc, board.f3)
    False -> acc
  }
  let acc = case predicate(board.g3) {
    True -> yielder.prepend(acc, board.g3)
    False -> acc
  }
  let acc = case predicate(board.h3) {
    True -> yielder.prepend(acc, board.h3)
    False -> acc
  }
  let acc = case predicate(board.a2) {
    True -> yielder.prepend(acc, board.a2)
    False -> acc
  }
  let acc = case predicate(board.b2) {
    True -> yielder.prepend(acc, board.b2)
    False -> acc
  }
  let acc = case predicate(board.c2) {
    True -> yielder.prepend(acc, board.c2)
    False -> acc
  }
  let acc = case predicate(board.d2) {
    True -> yielder.prepend(acc, board.d2)
    False -> acc
  }
  let acc = case predicate(board.e2) {
    True -> yielder.prepend(acc, board.e2)
    False -> acc
  }
  let acc = case predicate(board.f2) {
    True -> yielder.prepend(acc, board.f2)
    False -> acc
  }
  let acc = case predicate(board.g2) {
    True -> yielder.prepend(acc, board.g2)
    False -> acc
  }
  let acc = case predicate(board.h2) {
    True -> yielder.prepend(acc, board.h2)
    False -> acc
  }
  let acc = case predicate(board.a1) {
    True -> yielder.prepend(acc, board.a1)
    False -> acc
  }
  let acc = case predicate(board.b1) {
    True -> yielder.prepend(acc, board.b1)
    False -> acc
  }
  let acc = case predicate(board.c1) {
    True -> yielder.prepend(acc, board.c1)
    False -> acc
  }
  let acc = case predicate(board.d1) {
    True -> yielder.prepend(acc, board.d1)
    False -> acc
  }
  let acc = case predicate(board.e1) {
    True -> yielder.prepend(acc, board.e1)
    False -> acc
  }
  let acc = case predicate(board.f1) {
    True -> yielder.prepend(acc, board.f1)
    False -> acc
  }
  let acc = case predicate(board.g1) {
    True -> yielder.prepend(acc, board.g1)
    False -> acc
  }
  let acc = case predicate(board.h1) {
    True -> yielder.prepend(acc, board.h1)
    False -> acc
  }
  acc
}

pub fn at(board: Board(a), square: square.Square) {
  case square {
    square.Square(0) -> board.a8
    square.Square(1) -> board.b8
    square.Square(2) -> board.c8
    square.Square(3) -> board.d8
    square.Square(4) -> board.e8
    square.Square(5) -> board.f8
    square.Square(6) -> board.g8
    square.Square(7) -> board.h8
    square.Square(16) -> board.a7
    square.Square(17) -> board.b7
    square.Square(18) -> board.c7
    square.Square(19) -> board.d7
    square.Square(20) -> board.e7
    square.Square(21) -> board.f7
    square.Square(22) -> board.g7
    square.Square(23) -> board.h7
    square.Square(32) -> board.a6
    square.Square(33) -> board.b6
    square.Square(34) -> board.c6
    square.Square(35) -> board.d6
    square.Square(36) -> board.e6
    square.Square(37) -> board.f6
    square.Square(38) -> board.g6
    square.Square(39) -> board.h6
    square.Square(48) -> board.a5
    square.Square(49) -> board.b5
    square.Square(50) -> board.c5
    square.Square(51) -> board.d5
    square.Square(52) -> board.e5
    square.Square(53) -> board.f5
    square.Square(54) -> board.g5
    square.Square(55) -> board.h5
    square.Square(64) -> board.a4
    square.Square(65) -> board.b4
    square.Square(66) -> board.c4
    square.Square(67) -> board.d4
    square.Square(68) -> board.e4
    square.Square(69) -> board.f4
    square.Square(70) -> board.g4
    square.Square(71) -> board.h4
    square.Square(80) -> board.a3
    square.Square(81) -> board.b3
    square.Square(82) -> board.c3
    square.Square(83) -> board.d3
    square.Square(84) -> board.e3
    square.Square(85) -> board.f3
    square.Square(86) -> board.g3
    square.Square(87) -> board.h3
    square.Square(96) -> board.a2
    square.Square(97) -> board.b2
    square.Square(98) -> board.c2
    square.Square(99) -> board.d2
    square.Square(100) -> board.e2
    square.Square(101) -> board.f2
    square.Square(102) -> board.g2
    square.Square(103) -> board.h2
    square.Square(112) -> board.a1
    square.Square(113) -> board.b1
    square.Square(114) -> board.c1
    square.Square(115) -> board.d1
    square.Square(116) -> board.e1
    square.Square(117) -> board.f1
    square.Square(118) -> board.g1
    square.Square(119) -> board.h1
    _ -> panic as "Bad square"
  }
}

pub fn set(board: Board(a), square: square.Square, value: a) {
  case square {
    square.Square(0) -> Board(..board, a8: value)
    square.Square(1) -> Board(..board, b8: value)
    square.Square(2) -> Board(..board, c8: value)
    square.Square(3) -> Board(..board, d8: value)
    square.Square(4) -> Board(..board, e8: value)
    square.Square(5) -> Board(..board, f8: value)
    square.Square(6) -> Board(..board, g8: value)
    square.Square(7) -> Board(..board, h8: value)
    square.Square(16) -> Board(..board, a7: value)
    square.Square(17) -> Board(..board, b7: value)
    square.Square(18) -> Board(..board, c7: value)
    square.Square(19) -> Board(..board, d7: value)
    square.Square(20) -> Board(..board, e7: value)
    square.Square(21) -> Board(..board, f7: value)
    square.Square(22) -> Board(..board, g7: value)
    square.Square(23) -> Board(..board, h7: value)
    square.Square(32) -> Board(..board, a6: value)
    square.Square(33) -> Board(..board, b6: value)
    square.Square(34) -> Board(..board, c6: value)
    square.Square(35) -> Board(..board, d6: value)
    square.Square(36) -> Board(..board, e6: value)
    square.Square(37) -> Board(..board, f6: value)
    square.Square(38) -> Board(..board, g6: value)
    square.Square(39) -> Board(..board, h6: value)
    square.Square(48) -> Board(..board, a5: value)
    square.Square(49) -> Board(..board, b5: value)
    square.Square(50) -> Board(..board, c5: value)
    square.Square(51) -> Board(..board, d5: value)
    square.Square(52) -> Board(..board, e5: value)
    square.Square(53) -> Board(..board, f5: value)
    square.Square(54) -> Board(..board, g5: value)
    square.Square(55) -> Board(..board, h5: value)
    square.Square(64) -> Board(..board, a4: value)
    square.Square(65) -> Board(..board, b4: value)
    square.Square(66) -> Board(..board, c4: value)
    square.Square(67) -> Board(..board, d4: value)
    square.Square(68) -> Board(..board, e4: value)
    square.Square(69) -> Board(..board, f4: value)
    square.Square(70) -> Board(..board, g4: value)
    square.Square(71) -> Board(..board, h4: value)
    square.Square(80) -> Board(..board, a3: value)
    square.Square(81) -> Board(..board, b3: value)
    square.Square(82) -> Board(..board, c3: value)
    square.Square(83) -> Board(..board, d3: value)
    square.Square(84) -> Board(..board, e3: value)
    square.Square(85) -> Board(..board, f3: value)
    square.Square(86) -> Board(..board, g3: value)
    square.Square(87) -> Board(..board, h3: value)
    square.Square(96) -> Board(..board, a2: value)
    square.Square(97) -> Board(..board, b2: value)
    square.Square(98) -> Board(..board, c2: value)
    square.Square(99) -> Board(..board, d2: value)
    square.Square(100) -> Board(..board, e2: value)
    square.Square(101) -> Board(..board, f2: value)
    square.Square(102) -> Board(..board, g2: value)
    square.Square(103) -> Board(..board, h2: value)
    square.Square(112) -> Board(..board, a1: value)
    square.Square(113) -> Board(..board, b1: value)
    square.Square(114) -> Board(..board, c1: value)
    square.Square(115) -> Board(..board, d1: value)
    square.Square(116) -> Board(..board, e1: value)
    square.Square(117) -> Board(..board, f1: value)
    square.Square(118) -> Board(..board, g1: value)
    square.Square(119) -> Board(..board, h1: value)
    _ -> panic as "Bad square"
  }
}
