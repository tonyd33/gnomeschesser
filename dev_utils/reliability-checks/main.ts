import { Chess } from "chess.js";
import process from "node:process";
import yargs from "yargs";
import { hideBin } from "yargs/helpers";
import winston from "winston";
import { Engine as UCIEngine } from "node-uci";

const logger = winston.createLogger({
  level: "debug",
  format: winston.format.prettyPrint(),
  transports: [new winston.transports.Console()],
});

type Result<T, E> =
  | { ok: true; value: T }
  | { ok: false; err: E };

type HTTPEngine = { url: string };

type Engine =
  | { proto: "http"; engine: HTTPEngine }
  | { proto: "uci"; engine: UCIEngine }
  | { proto: "random" };

type Context = { fen: string };

type Contextualized<A> = { context: Context; value: A };

type Stats = {
  failedMoves: Contextualized<string>[];
  timeouts: Contextualized<number>[];
  movetime: Contextualized<number>[];
};

function avg(xs: number[]) {
  return xs.reduce((acc, x) => acc + x, 0) / xs.length;
}

function stddev(xs: number[]) {
  const u = avg(xs);
  return Math.sqrt(xs.reduce((acc, x) => acc + (x - u) ** 2) / xs.length);
}

function mergeStats(s1: Stats, s2: Stats): Stats {
  return {
    failedMoves: [...s1.failedMoves, ...s2.failedMoves],
    timeouts: [...s1.timeouts, ...s2.timeouts],
    movetime: [...s1.movetime, ...s2.movetime],
  };
}

const emptyStats: Stats = { failedMoves: [], timeouts: [], movetime: [] };

function formatStats(stats: Stats): string {
  return `Failed moves: ${stats.failedMoves.length}
Timeouts: ${stats.timeouts.length}
Movetime avg: ${avg(stats.movetime.map((x) => x.value))}
Movetime stddev: ${stddev(stats.movetime.map((x) => x.value))}
`;
}

async function runStatsN(f: () => Promise<Stats>, n: number) {
  let stats = emptyStats;
  for (let i = 0; i < n; i++) {
    logger.debug(`Run ${i}/${n}`);
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

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

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

  const contextualizeGame = contextualize({ fen: chess.fen() });
  while (stats.failedMoves.length < 3 && stats.timeouts.length < 10) {
    // logger.debug("Asking for move");
    const start = Date.now();
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
    const end = Date.now();
    if (!moveResult.ok) {
      if (moveResult.err == "timeout") {
        const timeouts = [contextualizeGame(1)];
        stats = mergeStats(stats, { timeouts, failedMoves: [], movetime: [] });
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
        const failedMoves = [contextualizeGame(move)];
        stats = mergeStats(stats, { timeouts: [], failedMoves, movetime: [] });
        logger.warn(`Failed to make a move. Retrying...`);
        continue;
      } else {
        throw new Error(makeMoveResult.err);
      }
    }

    stats = mergeStats(stats, {
      ...emptyStats,
      movetime: [contextualizeGame(start - end)],
    });
    break;
  }

  return stats;
}

async function makeEngineMove(chess: Chess, engine: Engine) {
  switch (engine.proto) {
    case "http":
      return askHttp({ chess, url: engine.engine.url });
    case "random": {
      const availableMoves = chess.moves();
      const randomIndex = Math.min(
        Math.floor(Math.random() * availableMoves.length),
        availableMoves.length - 1,
      );
      chess.move(availableMoves[randomIndex]);
      return emptyStats;
    }
    case "uci": {
      await engine.engine.isready();
      await engine.engine.position(chess.fen());
      const result = await race(
        (): Promise<{ bestmove: string }> =>
          engine.engine.go({ movetime: 5000 }),
        10000,
      );
      if (!result.ok) {
        throw new Error(result.err);
      }
      chess.move(result.value.bestmove);
      return emptyStats;
    }
    default:
      throw new Error("absurd");
  }
}

async function play(engine1: Engine, engine2: Engine) {
  const chess = new Chess();
  let stats = emptyStats;

  while (true) {
    stats = mergeStats(stats, await makeEngineMove(chess, engine1));
    if (chess.isGameOver()) {
      break;
    }
    // console.log(chess.ascii());

    stats = mergeStats(stats, await makeEngineMove(chess, engine2));
    if (chess.isGameOver()) {
      break;
    }
    // console.log(chess.ascii());
  }
  return stats;
}

async function parseEngineSpec(spec: string): Promise<Result<Engine, string>> {
  const parseProto = (s: string): Result<"http" | "uci" | "random", string> => {
    if (s.startsWith("proto:http")) {
      return { ok: true, value: "http" };
    } else if (s.startsWith("proto:uci")) {
      return { ok: true, value: "uci" };
    } else if (s.startsWith("proto:random")) {
      return { ok: true, value: "random" };
    } else {
      return { ok: false, err: "Expected http or uci" };
    }
  };

  const parseURL = (s: string): Result<string, string> => {
    if (s.startsWith("url:")) {
      return { ok: true, value: s.slice("url:".length) };
    } else {
      return { ok: false, err: "Expected url" };
    }
  };

  const parsePath = (s: string): Result<string, string> => {
    if (s.startsWith("path:")) {
      return { ok: true, value: s.slice("path:".length) };
    } else {
      return { ok: false, err: "Expected url" };
    }
  };

  const parts = spec.split(",");
  if (parts.length !== 2) {
    return { ok: false, err: "not enough parts" };
  }
  const proto = parseProto(parts[0]);
  if (!proto.ok) return proto;

  switch (proto.value) {
    case "http": {
      const url = parseURL(parts[1]);
      return url.ok
        ? { ok: true, value: { proto: "http", engine: { url: url.value } } }
        : url;
    }
    case "uci": {
      const path = parsePath(parts[1]);
      if (!path.ok) return path;
      const uciEngine = new UCIEngine(path.value);
      await uciEngine.init();
      return {
        ok: true,
        value: { proto: "uci", engine: uciEngine },
      };
    }
    case "random": {
      return { ok: true, value: { proto: "random" } };
    }
    default:
      return { ok: false, err: "Bad parse" };
  }
}

async function main() {
  const opts = await yargs()
    .scriptName("reliability-test")
    .option("engine", {
      type: "string",
      array: true,
      demandOption: true,
      describe: "engines",
    })
    .option("n", {
      type: "number",
      default: 5,
    })
    .parse(hideBin(process.argv));

  const engines = await Promise.all(opts
    .engine
    .map((x) =>
      parseEngineSpec(x).then((e) => {
        if (!e.ok) {
          throw new Error("bad engine");
        }
        return e.value;
      })
    ));

  const run = () => {
    if (engines.length !== 2) {
      throw new Error("needed 2 engines");
    }
    return play(engines[0], engines[1]);
  };

  const stats = await runStatsN(run, opts.n);

  console.log(stats);
  console.log(formatStats(stats));
}

await main();
