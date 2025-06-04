import { Chess } from "chess.js";
import process from "node:process";
import yargs from "yargs";
import { hideBin } from "yargs/helpers";
import winston from "winston";

const logger = winston.createLogger({
  level: "debug",
  format: winston.format.prettyPrint(),
  transports: [new winston.transports.Console()],
});

type Result<T, E> =
  | { ok: true; value: T }
  | { ok: false; err: E };

type HTTPEngine = { url: string };

type UCIEngine = { enginePath: string };

type Engine =
  | { proto: "http"; engine: HTTPEngine }
  | { proto: "uci"; engine: UCIEngine };

type Context = { fen: string };

type Contextualized<A> = { context: Context; value: A };

type Stats = {
  failedMoves: Contextualized<string>[];
  timeouts: Contextualized<number>[];
};

function mergeStats(s1: Stats, s2: Stats): Stats {
  return {
    failedMoves: [...s1.failedMoves, ...s2.failedMoves],
    timeouts: [...s1.timeouts, ...s2.timeouts],
  };
}

const emptyStats: Stats = { failedMoves: [], timeouts: [] };

async function runStatsN(f: () => Promise<Stats>, n: number) {
  let stats = emptyStats;
  for (let i = 0; i < n; i++) {
    const stat = await f();
    stats = mergeStats(stats, stat);
  }

  return stats;
}

const contextualize = (context: Context) => <A>(a: A): Contextualized<A> => ({
  context,
  value: a,
});

const decontextualize = <A>(contextualized: Contextualized<A>): A =>
  contextualized.value;

async function race<A>(
  f: () => Promise<A>,
  time: number,
): Promise<Result<A, string>> {
  return await Promise.race([
    f().then((a): Result<A, string> => ({ ok: true, value: a })),
    new Promise<Result<A, string>>((resolve) =>
      setTimeout(
        () => resolve({ ok: false, err: "timeout" }),
        time,
      )
    ),
  ]);
}

const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms))

async function askHttp(
  { chess, url }: { chess: Chess; url: string },
): Promise<Stats> {
  let stats = emptyStats;

  const makeMove = (move: string): Result<null, string> => {
    try {
      chess.move(move);
      return { ok: true, value: null };
    } catch (e) {
      if (e instanceof Error) {
        return { ok: false, err: e.message };
      } else {
        throw e;
      }
    }
  };

  while (stats.failedMoves.length < 3 && stats.timeouts.length < 10) {
    logger.debug("Asking for move");
    const moveResult = await race(() =>
      fetch(
        url,
        {
          method: "POST",
          body: JSON.stringify({
            fen: chess.fen(),
            turn: chess.turn() === "w" ? "white" : "black",
            failed_moves: stats.failedMoves.map(decontextualize),
          }),
        },
      )
        .then((x) => x.text()), 5000);
    if (!moveResult.ok) {
      if (moveResult.err == "timeout") {
        const timeouts = [contextualize({ fen: chess.fen() })(1)];
        stats = mergeStats(stats, { timeouts, failedMoves: [] });
        logger.warn(`Got a timeout. Retrying...`);
        sleep(5000);
        continue;
      } else {
        throw new Error(moveResult.err);
      }
    }

    const move = moveResult.value;
    const makeMoveResult = makeMove(move);
    if (!makeMoveResult.ok) {
      if (makeMoveResult.err.match(/^Invalid move/)) {
        const failedMoves = [contextualize({ fen: chess.fen() })(move)];
        stats = mergeStats(stats, { timeouts: [], failedMoves });
        logger.warn(`Failed to make a move. Retrying...`);
        continue;
      } else {
        throw new Error(makeMoveResult.err);
      }
    }

    break;
  }
  return stats;
}

/**
 * Play random moves against an HTTP engine for a game.
 */
async function playRandom({ url }: HTTPEngine) {
  const chess = new Chess();
  let stats = emptyStats;

  while (true) {
    // Ask for a move.
    const stat = await askHttp({ chess, url });
    stats = mergeStats(stats, stat);

    if (chess.isCheckmate()) {
      break;
    }

    const availableMoves = chess.moves();
    const randomIndex = Math.min(
      Math.floor(Math.random() * availableMoves.length),
      availableMoves.length - 1,
    );
    chess.move(availableMoves[randomIndex]);
    if (chess.isCheckmate()) {
      break;
    }
  }

  return stats;
}

/**
 * Play against the same engine
 */
async function playSame({ url }: HTTPEngine) {
  const chess = new Chess();
  let stats = emptyStats;
  while (true) {
    // Ask for a move.
    let stat = await askHttp({ chess, url });
    stats = mergeStats(stats, stat);

    if (chess.isCheckmate()) {
      break;
    }

    // Ask for a move.
    stat = await askHttp({ chess, url });
    stats = mergeStats(stats, stat);

    if (chess.isCheckmate()) {
      break;
    }
  }

  return stats;
}

async function main() {
  const opts = await yargs()
    .scriptName("reliability-test")
    .option("url", {
      type: "string",
      demandOption: true,
      describe: "engine endpoint",
    })
    .option("method", {
      choices: ["random", "same"],
      default: "random",
    })
    .option("n", {
      type: "number",
      default: 5,
    })
    .parse(hideBin(process.argv));

  const run = () => {
    logger.debug(`Running method ${opts.method}`);
    switch (opts.method) {
      case "random":
        return playRandom({ url: opts.url });
      case "same":
        return playSame({ url: opts.url });
      default:
        throw new Error("absurd");
    }
  };

  const stats = await runStatsN(run, opts.n);

  console.log(stats);
}

await main();
