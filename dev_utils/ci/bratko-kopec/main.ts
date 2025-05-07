import process from "node:process";
import path from "node:path";
import yargs from "yargs";
import { hideBin } from "yargs/helpers";
import { Engine } from "node-uci";

type TestCase = { fen: string; bms: string[]; id: string };
type TestResult = {
  ok: boolean;
  id: string;
  input: string;
  expected: string;
  got: string;
};

const testCases: TestCase[] = [
  {
    fen: "1k1r4/pp1b1R2/3q2pp/4p3/2B5/4Q3/PPP2B2/2K5 b - - 0 1",
    bms: ["d6d1"],
    id: "BK.01",
  },
  {
    fen: "3r1k2/4npp1/1ppr3p/p6P/P2PPPP1/1NR5/5K2/2R5 w - - 0 1",
    bms: ["d4d5"],
    id: "BK.02",
  },
  {
    fen: "2q1rr1k/3bbnnp/p2p1pp1/2pPp3/PpP1P1P1/1P2BNNP/2BQ1PRK/7R b - - 0 1",
    bms: ["f6f5"],
    id: "BK.03",
  },
  {
    fen: "rnbqkb1r/p3pppp/1p6/2ppP3/3N4/2P5/PPP1QPPP/R1B1KB1R w KQkq - 0 1",
    bms: ["e5e6"],
    id: "BK.04",
  },
  {
    fen: "r1b2rk1/2q1b1pp/p2ppn2/1p6/3QP3/1BN1B3/PPP3PP/R4RK1 w - - 0 1",
    bms: ["c3d5", "a2a4"],
    id: "BK.05",
  },
  {
    fen: "2r3k1/pppR1pp1/4p3/4P1P1/5P2/1P4K1/P1P5/8 w - - 0 1",
    bms: ["g5g6"],
    id: "BK.06",
  },
  {
    fen: "1nk1r1r1/pp2n1pp/4p3/q2pPp1N/b1pP1P2/B1P2R2/2P1B1PP/R2Q2K1 w - - 0 1",
    bms: ["h5f6"],
    id: "BK.07",
  },
  {
    fen: "4b3/p3kp2/6p1/3pP2p/2pP1P2/4K1P1/P3N2P/8 w - - 0 1",
    bms: ["f4f5"],
    id: "BK.08",
  },
  {
    fen: "2kr1bnr/pbpq4/2n1pp2/3p3p/3P1P1B/2N2N1Q/PPP3PP/2KR1B1R w - - 0 1",
    bms: ["f4f5"],
    id: "BK.09",
  },
  {
    fen: "3rr1k1/pp3pp1/1qn2np1/8/3p4/PP1R1P2/2P1NQPP/R1B3K1 b - - 0 1",
    bms: ["c6e5"],
    id: "BK.10",
  },
  {
    fen: "2r1nrk1/p2q1ppp/bp1p4/n1pPp3/P1P1P3/2PBB1N1/4QPPP/R4RK1 w - - 0 1",
    bms: ["f2f4"],
    id: "BK.11",
  },
  {
    fen: "r3r1k1/ppqb1ppp/8/4p1NQ/8/2P5/PP3PPP/R3R1K1 b - - 0 1",
    bms: ["d7f5"],
    id: "BK.12",
  },
  {
    fen: "r2q1rk1/4bppp/p2p4/2pP4/3pP3/3Q4/PP1B1PPP/R3R1K1 w - - 0 1",
    bms: ["b2b4"],
    id: "BK.13",
  },
  {
    fen: "rnb2r1k/pp2p2p/2pp2p1/q2P1p2/8/1Pb2NP1/PB2PPBP/R2Q1RK1 w - - 0 1",
    bms: ["d1d2", "d1e1"],
    id: "BK.14",
  },
  {
    fen: "2r3k1/1p2q1pp/2b1pr2/p1pp4/6Q1/1P1PP1R1/P1PN2PP/5RK1 w - - 0 1",
    bms: ["g4g7"],
    id: "BK.15",
  },
  {
    fen: "r1bqkb1r/4npp1/p1p4p/1p1pP1B1/8/1B6/PPPN1PPP/R2Q1RK1 w kq - 0 1",
    bms: ["d2e4"],
    id: "BK.16",
  },
  {
    fen:
      "r2q1rk1/1ppnbppp/p2p1nb1/3Pp3/2P1P1P1/2N2N1P/PPB1QP2/R1B2RK1 b - - 0 1",
    bms: ["h7h5"],
    id: "BK.17",
  },
  {
    fen: "r1bq1rk1/pp2ppbp/2np2p1/2n5/P3PP2/N1P2N2/1PB3PP/R1B1QRK1 b - - 0 1",
    bms: ["c5b3"],
    id: "BK.18",
  },
  {
    fen: "3rr3/2pq2pk/p2p1pnp/8/2QBPP2/1P6/P5PP/4RRK1 b - - 0 1",
    bms: ["e8e4"],
    id: "BK.19",
  },
  {
    fen: "r4k2/pb2bp1r/1p1qp2p/3pNp2/3P1P2/2N3P1/PPP1Q2P/2KRR3 w - - 0 1",
    bms: ["g3g4"],
    id: "BK.20",
  },
  {
    fen: "3rn2k/ppb2rpp/2ppqp2/5N2/2P1P3/1P5Q/PB3PPP/3RR1K1 w - - 0 1",
    bms: ["f5h6"],
    id: "BK.21",
  },
  {
    fen: "2r2rk1/1bqnbpp1/1p1ppn1p/pP6/N1P1P3/P2B1N1P/1B2QPP1/R2R2K1 b - - 0 1",
    bms: ["b7e4"],
    id: "BK.22",
  },
  {
    fen: "r1bqk2r/pp2bppp/2p5/3pP3/P2Q1P2/2N1B3/1PP3PP/R4RK1 b kq - 0 1",
    bms: ["f7f6"],
    id: "BK.23",
  },
  {
    fen: "r2qnrnk/p2b2b1/1p1p2pp/2pPpp2/1PP1P3/PRNBB3/3QNPPP/5RK1 w - - 0 1",
    bms: ["f2f4"],
    id: "BK.24",
  },
];

function chunk<A>(n: number, xs: A[]): A[][] {
  if (n >= xs.length) return [xs];
  return [xs.slice(0, n), ...chunk(n, xs.slice(n))];
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Seeded PRNG
 * https://stackoverflow.com/a/47593316
 */
function mulberry32(seed: number) {
  return function () {
    let t = seed += 0x6D2B79F5;
    t = Math.imul(t ^ t >>> 15, t | 1);
    t ^= t + Math.imul(t ^ t >>> 7, t | 61);
    return ((t ^ t >>> 14) >>> 0) / 4294967296;
  };
}

function generateReport(results: TestResult[]): string {
  const numPassed = results.filter((x) => x.ok).length;
  const numFailed = results.length - numPassed;
  const failedTableRows = results
    .filter((x) => !x.ok)
    .map((x) => `| ${x.id} | ${x.input} | ${x.expected} | ${x.got} |`)
    .join("\n");

  const failureDetails = `
## 📚 Detailed failure report

For more information on each test id, see the [Bratko-Kopec test wiki](https://www.chessprogramming.org/Bratko-Kopec_Test#EPD-Record) and see the tests at \`dev_utils/ci/bratko-kopec/main.ts\`

| id | input | expected | got |
| -- |  --   |    --    | --  |
${failedTableRows}
`;
  let output = `# 📝 Bratko-Kopec Report

## 📍 Summary

* ✅ ${numPassed} passed
* ❌ ${numFailed} failed
* 💡 ${results.length} total
* 🧮 ${(numPassed * 100 / results.length).toFixed(2)}% success
`;

  if (numFailed > 0) {
    output += "\n" + failureDetails;
  }

  return output;
}

async function runTestCase(
  tc: TestCase,
  { engine, timeout, depth }: {
    engine: Engine;
    timeout: number;
    depth?: number;
  },
): Promise<TestResult> {
  await engine.position(tc.fen, []);
  await engine.isready();
  const { bestmove }: { bestmove: string; info: string[] } = await engine
    .go({ movetime: timeout, depth });

  return {
    ok: tc.bms.includes(bestmove),
    id: tc.id,
    input: tc.fen,
    expected: tc.bms.join("/"),
    got: bestmove,
  };
}

async function runTestCases(
  tests: TestCase[],
  { enginePath, timeout, depth, rest }: {
    enginePath: string;
    timeout: number;
    rest: number;
    depth?: number;
  },
) {
  const results: TestResult[] = [];
  const engine = new Engine(enginePath);

  try {
    await engine.init();
    await engine.isready();
    for await (const test of tests) {
      process.stderr.write(`⏰ ${test.id}: RUN\n`);

      const result = await runTestCase(test, { engine, timeout, depth });

      if (result.ok) {
        process.stderr.write(`✅ ${test.id}: OK\n`);
      } else {
        process.stderr.write(`❌ ${test.id}: FAIL\n`);
      }
      results.push(result);

      await sleep(rest);
    }
  } catch (err) {
    if (err instanceof Error) {
      process.stderr.write(`Error: ${err.message}\n`);
    } else {
      process.stderr.write(`Unknown error\n`);
    }
  } finally {
    engine.quit();
  }
  return results;
}

async function main() {
  const opts = await yargs()
    .scriptName("bratko-kopec")
    .usage("$0 <cmd> [args]")
    .option("workers", {
      alias: "w",
      type: "number",
      demandOption: true,
      default: 1,
      describe: "number of workers",
    })
    .option("timeout", {
      alias: "t",
      type: "number",
      default: 10000,
      describe: "timeout (ms)",
    })
    .option("depth", {
      alias: "d",
      type: "number",
      describe: "depth to search",
    })
    .option("engine", {
      type: "string",
      demandOption: true,
      describe: "path to engine executable",
    })
    .option("match", {
      type: "array",
      string: true,
      alias: "m",
      default: [],
      describe: "only run tests matching this regex",
    })
    .option("rest", {
      type: "number",
      default: 1000,
      describe: "time (ms) to rest between tests",
    })
    .option("shuffle", {
      type: "boolean",
      default: false,
      describe: "shuffle test order",
    })
    .option("seed", {
      type: "number",
      default: undefined,
      describe: "seed for shuffling tests",
    })
    .parse(hideBin(process.argv));

  if (opts.workers <= 0) {
    process.stderr.write(`Bad workers: ${opts.workers}. Should be > 0\n`);
    process.exit(1);
  }

  let testsToRun = testCases;
  {
    const testRegexes = opts.match.map((re) => new RegExp(re));

    testsToRun = testsToRun
      .filter(({ id }) =>
        testRegexes.length === 0 || testRegexes.some((re) => re.test(id))
      );
    if (opts.shuffle) {
      const seed = opts.seed ?? ((Math.random() * 2 ** 32) >>> 0);
      const rand = mulberry32(seed);
      testsToRun = testsToRun.toSorted((_a, _b) => rand() - rand());
    }
  }

  const chunkSize = Math.max(Math.floor(testsToRun.length / opts.workers), 1);
  const tasks = chunk(chunkSize, testsToRun);

  const engineAbsPath = path.join(process.cwd(), opts.engine);

  const results = await Promise
    .all(
      tasks.map((tests) =>
        runTestCases(tests, {
          enginePath: engineAbsPath,
          timeout: opts.timeout,
          depth: opts.depth,
          rest: opts.rest,
        })
      ),
    )
    .then((xss) =>
      xss.flat().sort((x, y) => x.id == y.id ? 0 : (x.id < y.id ? -1 : 1))
    );
  process.stdout.write(generateReport(results) + "\n");
  process.exit(0);
}

main();
