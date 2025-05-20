import { TestCase } from "./types.ts";

/**
 * A suite of tests for hanging pieces. We should always pass these.
 */
const tests: TestCase[] = [
  {
    fen: "3k4/8/4q3/8/3N4/8/1R4R1/3K4 w - - 0 1",
    bms: ["d4e6"],
    id: "HG.01",
  },
  {
    fen: "rnb1kbnr/ppp1pppp/8/3p4/4P3/4q3/PPPP1PPP/RNBQKBNR w KQkq - 0 1",
    bms: ["d2e3", "f2e3"],
    id: "HG.02",
  },
  {
    fen: "rnb1kbnr/ppp1pppp/8/1q1p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1",
    bms: ["f1b5"],
    id: "HG.03",
  },
];

export default tests;
