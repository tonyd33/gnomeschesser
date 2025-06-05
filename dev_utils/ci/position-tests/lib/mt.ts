import { TestCase, TestSuite } from "./types.ts";

const tests: TestCase[] = [
  {
    fen: "6k1/P6p/5Kp1/2p5/1P3P2/2r5/8/8 w - - 0 1",
    bms: ["a7a8q", "a7a8r"],
    id: "MT.01",
  },
  {
    // Mate in 4
    // https://lichess.org/training/VL81U
    fen: "4rn1k/1r2q1bp/3pB1p1/p2P2P1/Np2Pp1R/1Pp1Q3/P1P5/1K5R w - - 0 29",
    bms: ["h4h7"],
    id: "MT.02",
  },
  {
    // Mate in 3
    // https://lichess.org/training/YqcxF
    fen: "8/5k2/1PR2p2/5ppp/8/4PKPP/1r6/8 b - - 8 41",
    bms: ["g5g4"],
    id: "MT.03",
  },
  // Mate in 1
  {
    fen: "8/5k2/1PR2p2/5p2/5Kp1/4P1P1/1r6/8 b - - 1 43",
    bms: ["b2f2"],
    id: "MT.04",
  },
];

const suite: TestSuite = {
  name: "Mate",
  comment:
    "A suite of tests to test mating. Failing to pass these may indicate something seriously wrong with our engine: maybe we aren't searching deep enough.",
  tests,
};

export default suite;
