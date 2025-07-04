import { TestCase, TestSuite } from "./types.ts";

/**
 * https://www.stmintz.com/ccc/index.php?id=392369
 */
const tests: TestCase[] = [
  {
    fen: "3k4/8/4K3/2R5/8/8/8/8 w - - 0 1",
    bms: [
      "c5c1",
      "c5c2",
      "c5c3",
      "c5c4",
      "c5c6",
    ],
    comment: "CCC post",
    id: "ZPTS.01",
  },
  {
    fen: "1k6/7R/2K5/8/8/8/8/8 w - - 0 1",
    bms: [
      "h7e7",
      "h7f7",
      "h7g7",
      "h7h1",
      "h7h2",
      "h7h3",
      "h7h4",
      "h7h5",
      "h7h6",
      "h7h8",
    ],
    comment: "CCC post",
    id: "ZPTS.02",
  },
  {
    fen: "8/3k4/8/8/3PK3/8/8/8 w - - 0 1",
    bms: [
      "e4d5",
    ],
    comment: "CCC post",
    id: "ZPTS.03",
  },
  {
    fen: "2k5/8/1K1P4/8/8/8/8/8 w - - 0 1",
    bms: [
      "b6c6",
    ],
    comment: "white wins",
    id: "ZPTS.04",
  },
  {
    fen: "8/8/8/4N3/8/7p/8/5K1k w - - 0 1",
    bms: [
      "e5g4",
    ],
    comment: "white mates",
    id: "ZPTS.05",
  },
  {
    fen: "8/8/1p1K4/Pp6/2k1p3/8/1P6/8 w - - 0 1",
    bms: [
      "a5a6",
    ],
    comment:
      "Kubbel 1927, 1 ... e3 2 a7 e2 3 a8/Q e1/Q 4 Qd5+ Kb4 5 Qd3!, white wins",
    id: "ZPTS.06",
  },
  {
    fen: "8/1p5k/1P1p4/3p4/3Pp2p/2K1P2p/7P/8 w - - 0 1",
    bms: [
      "c3b2",
    ],
    comment: "1 Kb2! Kg8 2 Ka1!!, draw",
    id: "ZPTS.07",
  },
  {
    fen: "8/4N3/8/8/8/2b1p3/p1K1P3/k7 w - - 0 1",
    bms: [
      "e7c6",
    ],
    comment: "white mates in 3",
    id: "ZPTS.08",
  },
  {
    fen: "8/8/7p/2R5/4pp1K/8/8/3k2b1 w - - 0 1",
    bms: [
      "c5c4",
    ],
    comment:
      "Kricheli 1986, 1 Rc4! e3 2 Rd4+! Kc2 3 Rxf4 e2 4 Re4 Kd2 5 Rxe2+ Kxe2 6 Kg4!, draw",
    id: "ZPTS.09",
  },
  {
    fen: "4KBkr/7p/6PP/4P3/8/3P1p2/8/8 w - - 0 1",
    bms: [
      "g6g7",
    ],
    comment: "CCC post 27.4.2004 by Gerd Isenberg, white wins",
    id: "ZPTS.10",
  },
  {
    fen: "8/p7/1p6/p7/kq1Q4/8/K7/8 w - - 0 1",
    bms: [
      "d4d3",
    ],
    comment:
      "post in Avler chess forum, mate in 13: 1.Qd3 a6 2.Qd7+ Qb5 3.Qd4+ Qb4 4.Qd3 Qb2+ 5.Kxb2 Kb4 6.Qc3+ Kb5 7.Qc7 Kb4 8.Qc6 a4 9.Kc2 a3 10.Qc3+ Ka4 11.Qc4+ Ka5 12.Kb3 b5 13.Qc7#",
    id: "ZPTS.11",
  },
  {
    fen: "8/8/p3R3/1p5p/1P5p/6rp/5K1p/7k w - - 0 1",
    bms: [
      "e6e1",
    ],
    comment: "CCC post by Eduard Nemeth, mate in 7",
    id: "ZPTS.12",
  },
  {
    fen: "8/5b2/p2k4/1p1p1p1p/1P1K1P1P/2P1PB2/8/8 w - - 0 1",
    bms: [
      "f3d1",
      "f3e2",
    ],
    comment:
      "CCC post by Sune Fischer, Averbakh 1954, white wins: 1.Be2 Be8 [1.-Bg6 2.Bd3 Bh7 3.Bf1 leads to instant zugzwang, be it after 3.-Bg6 4.Bg2 Bf7 5.Bf3 or after 3.-Bg8 4.Be2 Bf7 5.Bf3] 2.Bd3 Bg6 3.Bc2 Bh7 4.Bb3! Bg8 5.Bd1 Bf7 6.Bf3! and so on",
    id: "ZPTS.13",
  },
  {
    fen: "6k1/3p4/P2P4/8/5Kp1/1p4Q1/p5p1/b7 w - - 0 1",
    bms: [
      "g3g2",
    ],
    comment:
      "Kasparyan 1959, 1 ... Be5+ 2 Kf5! a1/Q 3 a7! Qxa7 4 Kg6! Qa1! 5 Qd5! Kh8 6 Qe4!!, white wins",
    id: "ZPTS.14",
  },
  {
    fen: "1r4RK/2n5/7k/8/8/8/8/8 b - - 0 1",
    bms: [
      "c7e8",
    ],
    comment:
      "Polgar - Kasparov, 1996: mate in 8: 1. ... Ne8 2.Rf8 Kg6 3.Rg8+ Kf7 4.Kh7 Rb5 5.Rf8+ Kxf8 6.Kg6 Rc5 7.Kh6 Kf7 8.Kh7 Rh5#",
    id: "ZPTS.15",
  },
  {
    fen: "k2N2K1/8/8/8/5R2/3n4/3p4/8 w - - 0 1",
    bms: [
      "f4f7",
    ],
    comment: "CCC post by Ed Schroeder, Troitzky",
    id: "ZPTS.16",
  },
  {
    fen: "8/8/1p1r1k2/p1pPN1p1/P3KnP1/1P6/8/3R4 b - - 0 1",
    bms: [
      "f4d5",
    ],
    comment: "CCC post 27.4.2004 by Gerd Isenberg",
    id: "ZPTS.17",
  },
  {
    fen: "8/6B1/p5p1/Pp4kp/1P5r/5P1Q/4q1PK/8 w - - 0 1",
    bms: [
      "h3h4",
    ],
    comment: "CCC post 10.9.2004 by Alvaro Begue",
    id: "ZPTS.18",
  },
  {
    fen: "n1QBq1k1/5p1p/5KP1/p7/8/8/8/8 w - - 0 1",
    bms: [
      "d8c7",
    ],
    comment:
      "CCC post, mate in 12: 1.Bc7 Qxc8 2.gxf7+ Kh8 3.Be5 Qc5 4.Bb2 Nc7 5.Ba1 a4 6.Bb2 a3 7.Ba1 a2 8.Bb2 a1Q 9.Bxa1 Nd5+ 10.Ke6+ Nc3 11.Bxc3+ Qe5+ 12.Bxe5#",
    id: "ZPTS.19",
  },
  {
    fen: "3nQ1k1/p2P2p1/1p6/8/5q1P/8/PP6/1K6 b - - 0 1",
    bms: [
      "g8h7",
    ],
    comment: "CCC post, draw, but h5 after Qf8 wins for white",
    id: "ZPTS.20",
  },
  {
    fen: "8/8/8/1B6/6p1/8/4KPpp/3N2kr w - - 0 1",
    bms: [
      "e2d3",
      "e2e3",
    ],
    comment:
      "CCC post by Tim Foden, id MES.831, white wins, 1. Kd3 g3 2. f4 Kf1 3. Kd2+ Kg1 4. Bd7 Kf1 5. Bh3 Rg1 6. Bg4 Rh1 7. Be2+ Kg1 8. Nc3 Kf2 9. Ne4+ Kg1 10. Ng5 Kf2 11. Nh3#",
    id: "ZPTS.21",
  },
  {
    fen: "4B3/8/p7/k2N4/7p/K6p/PP5P/2q5 w - - 0 1",
    bms: [
      "e8a4",
    ],
    comment: "CCC post by Tim Foden, id CCC.347609, white wins",
    id: "ZPTS.22",
  },
  {
    fen: "6Q1/8/8/7k/8/8/3p1pp1/3Kbrrb w - - 0 1",
    bms: [
      "g8g7",
    ],
    comment: "CCC post by Joachim Rang, mate in 4",
    id: "ZPTS.23",
  },
  {
    fen: "8/8/8/2p5/1pp5/brpp4/1pprp2P/qnkbK3 w - - 0 1",
    bms: [
      "h2h3",
    ],
    comment: "CCC post by Joachim Rang, mate in 15, h4 is only draw",
    id: "ZPTS.24",
  },
  {
    fen: "8/1B6/8/5p2/8/8/5Qrq/1K1R2bk w - - 0 1",
    bms: [
      "f2a7",
    ],
    comment: "CCC post by Tim Foden, id CCC.321759, mate in 3",
    id: "ZPTS.25",
  },
  {
    fen: "8/3p1p2/5Ppp/K2R2bk/4pPrr/6Pp/4B2P/3N4 w - - 0 1",
    bms: [
      "d1c3",
    ],
    comment:
      "CCC post by Tim Foden, id CCC.321751, mate in 4: 1.Nc3 e3 2.Rb5 d6 3.Nd5 Bxf4 4.Nxf4#",
    id: "ZPTS.26",
  },
  {
    fen: "8/8/p5p1/p2N3p/k2P3P/5P2/KP1qB3/8 w - - 0 1",
    bms: [
      "f3f4",
    ],
    comment:
      "white wins, derived from the more difficult ZPTS.28, Zugzwang after f4",
    id: "ZPTS.27",
  },
  {
    fen: "8/p5pq/8/p2N3p/k2P3P/8/KP3PB1/8 w - - 0 1",
    bms: [
      "g2e4",
    ],
    comment:
      "Kubbel 1925, 1.Be4!! Qh6 2.Bd3!! Qd2 [2...Qd6 3.b3#] 3.Be2 g6 [3...Qc2 4.Bd1 Qxd1 5.Nc3 - 3...a6 4.f3 g6 5.f4 -] 4.f3 a6 5.f4 Qc2 6.Bd1, Zugzwang after f4, white wins",
    id: "ZPTS.28",
  },
  {
    fen: "8/5p2/4b1p1/7R/5K1P/2r3B1/7N/4b1k1 w - - 0 1",
    bms: [
      "h2f3",
    ],
    comment:
      "Noam Elkies 1984, 1 Nf3+! Rxf3+! 2 Kxf3 Bg4+! 3 Kf4!! Bxg3+ 4 Kxg4 gxh5+ 5 Kh3!! Kf1 6 Kxg3 Ke2 7 Kf4 f6 8 Kf5 Kf3 9 Kxf6 Kg4 10 Ke5 Kh4 11 Kf4, draw",
    id: "ZPTS.29",
  },
  {
    fen: "5R2/2K5/1pP5/4k2p/3pp3/2p4N/B4N1b/n1R1B2b w - - 0 1",
    bms: [
      "c1c3",
    ],
    comment: "CCC post by Tim Foden, id CCC.321966, mate in 4",
    id: "ZPTS.30",
  },
];

const suite: TestSuite = {
  name: "Zugzwang",
  comment:
    "[Zugzwang test suite](https://www.stmintz.com/ccc/index.php?id=392369) from 2004",
  tests,
};

export default suite;
