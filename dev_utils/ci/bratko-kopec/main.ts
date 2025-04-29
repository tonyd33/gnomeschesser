import process from "node:process";
import child_process from "node:child_process";
import path from "node:path";

const robotUrl = "http://localhost:8000/move";

async function askRobot(fen: string): Promise<string> {
  return fetch(robotUrl, {
    method: "POST",
    body: JSON.stringify({
      fen: fen,
      turn: fen.split(" ")[1] === "w" ? "white" : "black",
      failed_moves: [],
    }),
  }).then((res) => res.text());
}

type TestCase = { fen: string; bms: string[]; id: string };
type TestResult = { ok: boolean; id: string; expected: string; got: string };

const testCases: TestCase[] = [
  {
    fen: "1k1r4/pp1b1R2/3q2pp/4p3/2B5/4Q3/PPP2B2/2K5 b - - 0 1",
    bms: ["Qd1+"],
    id: "BK.01",
  },
  {
    fen: "3r1k2/4npp1/1ppr3p/p6P/P2PPPP1/1NR5/5K2/2R5 w - - 0 1",
    bms: ["d5"],
    id: "BK.02",
  },
  {
    fen: "2q1rr1k/3bbnnp/p2p1pp1/2pPp3/PpP1P1P1/1P2BNNP/2BQ1PRK/7R b - - 0 1",
    bms: ["f5"],
    id: "BK.03",
  },
  {
    fen: "rnbqkb1r/p3pppp/1p6/2ppP3/3N4/2P5/PPP1QPPP/R1B1KB1R w KQkq - 0 1",
    bms: ["e6"],
    id: "BK.04",
  },
  {
    fen: "r1b2rk1/2q1b1pp/p2ppn2/1p6/3QP3/1BN1B3/PPP3PP/R4RK1 w - - 0 1",
    bms: ["Nd5", "a4"],
    id: "BK.05",
  },
  {
    fen: "2r3k1/pppR1pp1/4p3/4P1P1/5P2/1P4K1/P1P5/8 w - - 0 1",
    bms: ["g6"],
    id: "BK.06",
  },
  {
    fen: "1nk1r1r1/pp2n1pp/4p3/q2pPp1N/b1pP1P2/B1P2R2/2P1B1PP/R2Q2K1 w - - 0 1",
    bms: ["Nf6"],
    id: "BK.07",
  },
  {
    fen: "4b3/p3kp2/6p1/3pP2p/2pP1P2/4K1P1/P3N2P/8 w - - 0 1",
    bms: ["f5"],
    id: "BK.08",
  },
  {
    fen: "2kr1bnr/pbpq4/2n1pp2/3p3p/3P1P1B/2N2N1Q/PPP3PP/2KR1B1R w - - 0 1",
    bms: ["f5"],
    id: "BK.09",
  },
  {
    fen: "3rr1k1/pp3pp1/1qn2np1/8/3p4/PP1R1P2/2P1NQPP/R1B3K1 b - - 0 1",
    bms: ["Ne5"],
    id: "BK.10",
  },
  {
    fen: "2r1nrk1/p2q1ppp/bp1p4/n1pPp3/P1P1P3/2PBB1N1/4QPPP/R4RK1 w - - 0 1",
    bms: ["f4"],
    id: "BK.11",
  },
  {
    fen: "r3r1k1/ppqb1ppp/8/4p1NQ/8/2P5/PP3PPP/R3R1K1 b - - 0 1",
    bms: ["Bf5"],
    id: "BK.12",
  },
  {
    fen: "r2q1rk1/4bppp/p2p4/2pP4/3pP3/3Q4/PP1B1PPP/R3R1K1 w - - 0 1",
    bms: ["b4"],
    id: "BK.13",
  },
  {
    fen: "rnb2r1k/pp2p2p/2pp2p1/q2P1p2/8/1Pb2NP1/PB2PPBP/R2Q1RK1 w - - 0 1",
    bms: ["Qd2", "Qe1"],
    id: "BK.14",
  },
  {
    fen: "2r3k1/1p2q1pp/2b1pr2/p1pp4/6Q1/1P1PP1R1/P1PN2PP/5RK1 w - - 0 1",
    bms: ["Qxg7+"],
    id: "BK.15",
  },
  {
    fen: "r1bqkb1r/4npp1/p1p4p/1p1pP1B1/8/1B6/PPPN1PPP/R2Q1RK1 w kq - 0 1",
    bms: ["Ne4"],
    id: "BK.16",
  },
  {
    fen:
      "r2q1rk1/1ppnbppp/p2p1nb1/3Pp3/2P1P1P1/2N2N1P/PPB1QP2/R1B2RK1 b - - 0 1",
    bms: ["h5"],
    id: "BK.17",
  },
  {
    fen: "r1bq1rk1/pp2ppbp/2np2p1/2n5/P3PP2/N1P2N2/1PB3PP/R1B1QRK1 b - - 0 1",
    bms: ["Nb3"],
    id: "BK.18",
  },
  {
    fen: "3rr3/2pq2pk/p2p1pnp/8/2QBPP2/1P6/P5PP/4RRK1 b - - 0 1",
    bms: ["Rxe4"],
    id: "BK.19",
  },
  {
    fen: "r4k2/pb2bp1r/1p1qp2p/3pNp2/3P1P2/2N3P1/PPP1Q2P/2KRR3 w - - 0 1",
    bms: ["g4"],
    id: "BK.20",
  },
  {
    fen: "3rn2k/ppb2rpp/2ppqp2/5N2/2P1P3/1P5Q/PB3PPP/3RR1K1 w - - 0 1",
    bms: ["Nh6"],
    id: "BK.21",
  },
  {
    fen: "2r2rk1/1bqnbpp1/1p1ppn1p/pP6/N1P1P3/P2B1N1P/1B2QPP1/R2R2K1 b - - 0 1",
    bms: ["Bxe4"],
    id: "BK.22",
  },
  {
    fen: "r1bqk2r/pp2bppp/2p5/3pP3/P2Q1P2/2N1B3/1PP3PP/R4RK1 b kq - 0 1",
    bms: ["f6"],
    id: "BK.23",
  },
  {
    fen: "r2qnrnk/p2b2b1/1p1p2pp/2pPpp2/1PP1P3/PRNBB3/3QNPPP/5RK1 w - - 0 1",
    bms: ["f4"],
    id: "BK.24",
  },
];

async function runTestCase(
  tc: TestCase,
): Promise<TestResult> {
  const timeout = new Promise<string>((resolve) =>
    setTimeout(() => resolve("timeout"), 10000)
  );
  const robotResponse = await Promise.race([askRobot(tc.fen), timeout]);

  return {
    ok: tc.bms.includes(robotResponse),
    id: tc.id,
    expected: tc.bms.join("/"),
    got: robotResponse,
  };
}

function generateReport(results: TestResult[]): string {
  const numPassed = results.filter((x) => x.ok).length;
  const numFailed = results.length - numPassed;
  const failedTableRows = results
    .filter((x) => !x.ok)
    .map((x) => `| ${x.id} | ${x.expected} | ${x.got} |`)
    .join("\n");

  const failureDetails = `
## 📚 Detailed failure report

For more information on each test id, see the [Bratko-Kopec test wiki](https://www.chessprogramming.org/Bratko-Kopec_Test#EPD-Record) and see the tests at \`dev_utils/ci/bratko-kopec/main.ts\`

| id | expected | got |
| -- |    --    | --  |
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

async function main() {
  const robot = child_process.spawn("gleam", ["run"], {
    cwd: path.join(
      new URL(".", import.meta.url).pathname,
      "../../../erlang_template",
    ),
    env: process.env,
    detached: true,
  });
  if (!robot.pid) {
    process.stderr.write("Failed to spawn robot\n");
    process.exit(1);
  }
  // Make sure this typechecks as a number for later
  const robotPid = robot.pid;

  const errorIfClosedEarly = () => {
    process.stdout.write("Robot failed to start\n");
    process.exit(1);
  };
  robot.on("close", errorIfClosedEarly);
  await new Promise<void>((resolve) => robot.stdout.on("data", resolve));
  robot.removeListener("close", errorIfClosedEarly);

  const exitGracefully = async () => {
    process.stderr.write("Exiting gracefully...\n");
    const death = new Promise((resolve) => robot.on("close", resolve));
    const timeout = new Promise<void>((resolve) =>
      setTimeout(() => {
        process.stderr.write("Robot didn't die before timeout\n");
        resolve();
      }, 5000)
    );
    // Kill process group. Works only on unix
    process.kill(-robotPid);
    await Promise.race([death, timeout]);
    process.stderr.write("Done.\n");
    process.exit(0);
  };
  process.on("SIGINT", exitGracefully);
  process.on("SIGTERM", exitGracefully);

  try {
    const results: TestResult[] = [];
    for (const tc of testCases) {
      process.stderr.write(`⏰ RUN: ${tc.id}\n`);
      const result = await runTestCase(tc);
      results.push(result);
      if (result.ok) {
        process.stderr.write(`✅ OK\n`);
      } else {
        process.stderr.write(`❌ FAIL\n`);
      }
    }
    process.stdout.write(generateReport(results) + "\n");
  } catch (err) {
    await new Promise((resolve) => setTimeout(resolve, 10000));
    if (err instanceof Error) {
      process.stderr.write(err.message + "\n");
    } else {
      process.stderr.write("Unknown error\n");
    }
  } finally {
    await exitGracefully();
  }
}

main();
