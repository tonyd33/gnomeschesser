import { TestCase, TestSuite } from "./types.ts";

/** */
const tests: TestCase[] = [
  {
    fen: "3r2k1/p3R1p1/1pq2pQp/8/8/1P4P1/PB3P1P/3b2K1 b - - 0 1",
    bms: [
      "c6h1",
    ],
    comment: "aka BWTC.0216",
    id: "Colditz.01",
  },
  {
    fen: "5r1k/5Bpp/p1p1Qb2/1pq5/4Pp2/7R/Pr3PPP/5RK1 w - - 0 1",
    bms: [
      "h3h7",
    ],
    id: "Colditz.02",
  },
  {
    fen: "3R4/1p3kpp/8/1P1b4/8/3r1N2/6PP/6K1 b - - 0 1",
    bms: [
      "d3d1",
    ],
    comment: "Asztalos - Nielsen, 1936",
    id: "Colditz.03",
  },
  {
    fen: "4rrk1/1bp2ppp/p7/1p1q4/3P1B2/2P3P1/PP5K/RN1Q2R1 b - - 0 1",
    bms: [
      "e8e1",
    ],
    comment: "Belinki - Pirogow, 1958",
    id: "Colditz.04",
  },
  {
    fen: "6k1/1p1qrpp1/p7/7p/PQ6/8/1PPp2PP/3R2K1 b - - 0 1",
    bms: [
      "e7e1",
    ],
    comment: "1953",
    id: "Colditz.05",
  },
  {
    fen: "r5rk/1p3p1p/p2N1Pq1/5R2/4Q3/7P/PPP4K/8 w - - 0 1",
    bms: [
      "f5g5",
    ],
    id: "Colditz.06",
  },
  {
    fen: "7k/p1p3pp/2r2q2/2P5/3Q2R1/3P3P/PP4PK/8 w - - 0 1",
    bms: [
      "g4f4",
    ],
    comment: "Duras - Wolf, 1907",
    id: "Colditz.07",
  },
  {
    fen: "5r1k/1b4p1/p6p/4Pp1q/2pNnP2/7N/PPQ3PP/5R1K b - - 0 1",
    bms: [
      "h5h3",
    ],
    comment: "Black to move and win. Torres vs Alekhine, Sevilla, 1922",
    id: "Colditz.08",
  },
  {
    fen: "r2r4/1p1R3p/5pk1/b1B1Pp2/p4P2/P7/1P5P/1K1R4 w - - 0 1",
    bms: [
      "d1g1",
    ],
    comment: "Moscow RUS 1960 Polugaevsky, Lev verses Szilagyi, Gyorgy c3 Rg1+",
    id: "Colditz.09",
  },
  {
    fen: "r4rk1/pbp2ppp/1p3Q2/8/2P5/2BR3P/PP2qPP1/5RK1 b - - 0 1",
    bms: [
      "e2g4",
    ],
    comment: "Fortress type position, but score is not completely stable.",
    id: "Colditz.10",
  },
  {
    fen: "r5k1/ppq2p1p/2p5/6r1/1P2pN2/P3PbP1/2Q2P2/R3R1K1 b - - 0 1",
    bms: [
      "c7f4",
    ],
    comment: "Peer - Moush, 1960",
    id: "Colditz.11",
  },
  {
    fen: "3r2k1/5p2/6p1/4b3/1P2P3/1R2P2p/P1K1N3/8 b - - 0 1",
    bms: [
      "d8d1",
    ],
    comment: "FRA-ch26 corr 1961 Javelle, Gabriel verses Dubois, Robert",
    id: "Colditz.12",
  },
  {
    fen: "r4rk1/5qpp/8/3Q4/1p6/1P5P/PB4P1/4R1K1 w - - 0 1",
    bms: [
      "e1e7",
    ],
    id: "Colditz.13",
  },
  {
    fen: "3r2k1/pRp2p2/6pQ/5b2/2B5/2qP2P1/P6P/6K1 w - - 0 1",
    bms: [
      "c4f7",
    ],
    comment: "Mecking vs Lian-Ann Tan, Petropolis, 1973",
    id: "Colditz.14",
  },
  {
    fen: "4bk1r/Q4ppp/1p2q3/8/4B3/8/P4PPP/4R1K1 w - - 0 1",
    bms: [
      "a7a3",
    ],
    comment: "Evans - Bisguier, 1958",
    id: "Colditz.15",
  },
  {
    fen: "7k/3q2p1/4p2p/4Pp2/1r3P2/p1pR4/P1P3PP/3Q3K b - - 0 1",
    bms: [
      "d7b5",
    ],
    id: "Colditz.16",
  },
  {
    fen: "6k1/4pp1p/3p2p1/2pP3q/1rNrPn2/1P6/P1QR1PPP/4R1K1 b - - 0 1",
    bms: [
      "b4c4",
    ],
    id: "Colditz.17",
  },
  {
    fen: "3r3k/1b2rpp1/p2qpN1p/1p6/4pP1Q/P5R1/1PP3PP/5R1K w - - 0 1",
    bms: [
      "h4g5",
    ],
    comment: "1946",
    id: "Colditz.18",
  },
  {
    fen: "8/7p/6pk/1P4r1/2P2QBK/R6P/6r1/6q1 b - - 0 1",
    bms: [
      "g1f2",
    ],
    comment: "1973 Giorgadze, Tamaz verses Kuyindzhi, Alexander A",
    id: "Colditz.19",
  },
  {
    fen: "r1b2rk1/2n1qppp/p1p1p3/1p2P3/4N3/3BP3/PP2QPPP/R4RK1 w - - 0 1",
    bms: [
      "e4f6",
    ],
    id: "Colditz.20",
  },
  {
    fen: "r3k1nr/p5b1/2qpp2p/1Q2n1p1/3N1p2/2P5/PP4PP/RNB2RK1 b - - 0 1",
    bms: [
      "e5f3",
    ],
    comment: "Sir Georg Alan Thomas - Horne, 1948",
    id: "Colditz.21",
  },
  {
    fen: "2q3k1/pbR1bppp/4r3/1Q2p3/8/4P1P1/P4PPK/1BBR4 b - - 0 1",
    bms: [
      "e6h6",
    ],
    comment: "Bruck - Gandolfi, 1939",
    id: "Colditz.22",
  },
  {
    fen: "2r3k1/5ppp/4p3/5q2/8/Pp1Q1P2/1P4PP/1K1R4 b - - 0 1",
    bms: [
      "c8d8",
    ],
    comment: "Mikenas - Aronin, 1957",
    id: "Colditz.23",
  },
  {
    fen: "r1br2k1/pp3ppp/1q1N4/3Q4/2B2n2/8/PPP3PP/R2K1R2 w - - 0 1",
    bms: [
      "d5f7",
    ],
    comment: "Unzicker B - Sarapu, 1970",
    id: "Colditz.24",
  },
  {
    fen: "2rq2k1/5pbp/6p1/pp6/3B4/1PnQ1N2/P4PPP/4R1K1 b - - 0 1",
    bms: [
      "g7d4",
    ],
    comment: "Just - Colditz, 1975",
    id: "Colditz.25",
  },
  {
    fen: "r3k1r1/pp3p1p/4p3/4n3/b1qNP3/4B2P/P4PP1/R1Q3KR b - - 0 1",
    bms: [
      "c4d4",
    ],
    comment: "Subaric - Trifunovic, 1947",
    id: "Colditz.26",
  },
  {
    fen: "4k3/1pp2b1p/2p2P2/r3P1R1/pr6/2N5/1PP4P/2KR4 w - - 0 1",
    bms: [
      "e5e6",
    ],
    comment: "Odessa",
    id: "Colditz.27",
  },
  {
    fen: "q4r1k/5p1p/p2pp2Q/1p2b3/8/2P2R2/P1P4P/6RK w - - 0 1",
    bms: [
      "g1g2",
    ],
    comment: "Soultan_Beieff - Borodin, 1943",
    id: "Colditz.28",
  },
  {
    fen: "q3rn1k/2QR4/pp2pp2/8/P1P5/1P4N1/6n1/6K1 w - - 0 1",
    bms: [
      "g3f5",
    ],
    comment: "White Mates in 6. Karpov vs Istvan Csom, Bad Lauterberg, 1977",
    id: "Colditz.29",
  },
  {
    fen: "5k2/p4r1p/3q4/2p1p1N1/P1P5/8/6QB/7K w - - 0 1",
    bms: [
      "g2a8",
    ],
    comment: "Moscow RUS",
    id: "Colditz.30",
  },
];

const suite: TestSuite = {
  name: "Colditz",
  comment:
    "See [forum post](https://www.talkchess.com/forum/viewtopic.php?t=62659).",
  tests,
};

export default suite;
