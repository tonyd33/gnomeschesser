import { TestCase } from "./types.ts";

/**
 * A suite of tests to test gaining an advantage.
 */
const tests: TestCase[] = [
  {
    // Win the queen for a rook
    // https://lichess.org/training/jIJhw
    fen: "1r1r2k1/6pp/3pq3/3Rp3/2Q1P3/1p3P2/PPP3PP/1K1R4 b - - 0 26",
    bms: ["d8c8"],
    id: "AV.01",
  },
  {
    // Win a queen and a knight
    // https://lichess.org/training/RwQxm
    fen: "r4r2/pp2Bpk1/2qP2p1/2p1n3/2Bb2Q1/5R2/PP5P/R6K w - - 9 25",
    bms: ["e7f6"],
    id: "AV.02",
  },
  {
    // https://lichess.org/training/rCkOs
    fen: "2kr1b1r/ppp2pp1/8/3pnP1p/4N1nq/7P/PPP1BPP1/R1BQ1RK1 w - - 0 13",
    bms: ["c1g5"],
    id: "AV.03",
  },
];

export default tests;
