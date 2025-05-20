import av from "./lib/av.ts";
import bk from "./lib/bk.ts";
import colditz from "./lib/colditz.ts";
import hg from "./lib/hg.ts";
import mt from "./lib/mt.ts";
import path from "node:path";
import process from "node:process";
import sbd from "./lib/sbd.ts";
import wac from "./lib/wac.ts";
import yargs from "yargs";
import zpts from "./lib/zpts.ts";
import { Engine } from "node-uci";
import { TestCase } from "./lib/types.ts";
import { hideBin } from "yargs/helpers";

type TestResult = {
  ok: boolean;
  id: string;
  input: string;
  expected: string;
  got: string;
};

const testCases: TestCase[] = [
  ...bk,
  ...wac,
  ...sbd,
  ...colditz,
  ...zpts,
  ...hg,
  ...mt,
  ...av,
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
  const { bestmove }: { bestmove: string; info: string[] } = await Promise.race(
    [
      engine.go({ movetime: timeout, depth }),
      new Promise((resolve) =>
        setTimeout(
          () => resolve({ bestmove: "timeout", info: [] }),
          timeout * 2,
        )
      ),
    ],
  );

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
  { enginePath, timeout, depth, rest, workerNum }: {
    enginePath: string;
    timeout: number;
    rest: number;
    depth?: number;
    workerNum: number;
  },
) {
  const results: TestResult[] = [];
  const engine = new Engine(enginePath);

  try {
    await engine.init();
    await engine.isready();
    for await (const test of tests) {
      process.stderr.write(`[WORKER ${workerNum}] ⏰ ${test.id}: RUN\n`);

      const result = await runTestCase(test, { engine, timeout, depth });

      if (result.ok) {
        process.stderr.write(`[WORKER ${workerNum}] ✅ ${test.id}: OK\n`);
      } else {
        process.stderr.write(`[WORKER ${workerNum}] ❌ ${test.id}: FAIL\n`);
      }
      results.push(result);

      await sleep(rest);
    }
  } catch (err) {
    if (err instanceof Error) {
      process.stderr.write(`[WORKER ${workerNum}] Error: ${err.message}\n`);
    } else {
      process.stderr.write(`[WORKER ${workerNum}] Unknown error\n`);
    }
    process.exit(1);
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

  const chunkSize = Math.max(Math.ceil(testsToRun.length / opts.workers), 1);
  const tasks = chunk(chunkSize, testsToRun);

  const engineAbsPath = path.join(process.cwd(), opts.engine);

  const results = await Promise
    .all(
      tasks.map((tests, workerNum) =>
        runTestCases(tests, {
          enginePath: engineAbsPath,
          timeout: opts.timeout,
          depth: opts.depth,
          rest: opts.rest,
          workerNum: workerNum + 1,
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
