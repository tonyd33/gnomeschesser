import fs from "node:fs";
import process from "node:process";
import yargs from "yargs";
import { hideBin } from "yargs/helpers";
import dotenv from "dotenv";
import equine from "equine";
import * as R from "ramda";
import { Chess } from "chess.js";

function tabulate(rows: string[][], colSep = "\t", rowSep = "\n"): string {
  const numCols = rows.reduce((n, row) => Math.max(n, row.length), 0);

  const maxWidths = rows.reduce<number[]>(
    R.pipe(
      // deno-lint-ignore no-explicit-any
      R.uncurryN(2, R.zip) as any,
      R.map(([n, cell]) => Math.max(n, cell.length)),
    ),
    R.repeat(0, numCols),
  );

  return R.flow(rows, [
    R.map(R.pipe(
      R.zip(maxWidths),
      R.map(([maxWidth, cell]) => cell.padEnd(maxWidth, " ")),
      R.join(colSep),
    )),
    R.join(rowSep),
  ]);
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

async function retryWithExponentialBackoff<A>(
  f: () => Promise<A>,
  opts: { maxRetries: number; rest: number },
) {
  let i = 0;
  let rest = opts.rest;
  while (true) {
    i++;
    // Try to do `f`. If it fails, sleep for `rest` ms and double the `rest`
    // before trying it again.
    try {
      return await f();
    } catch (e) {
      let message = "unknown error";
      if (e instanceof Error) {
        message = e.message;
      }
      process.stderr.write(
        `Failed ${i}/${opts.maxRetries} times with error ${message}\n`,
      );
      if (i >= opts.maxRetries) {
        throw e;
      } else {
        process.stderr.write(`Sleeping for ${rest}ms\n`);
        await sleep(rest);
        rest *= 2;
      }
    }
  }
}

async function main() {
  const opts = await yargs()
    .scriptName("upload-report")
    .option("pgn", {
      type: "string",
      demandOption: true,
      describe: "pgn file",
    })
    .option("rest", {
      type: "number",
      default: 1000,
      describe: "time (ms) to rest between uploads with exponential backoff",
    })
    .option("max-retries", {
      type: "number",
      default: 10,
      describe: "max number of retries before failing",
    })
    .option("title", {
      type: "string",
      default: "SPRT Results",
      describe: "title of the markdown result",
    })
    .parse(hideBin(process.argv));

  dotenv.config();
  const lichessKey = process.env["LICHESS_KEY"];
  if (!lichessKey) {
    process.stderr.write("Needed LICHESS_KEY set\n");
    process.exit(1);
  }

  equine.initialize(lichessKey);

  // Load PGNs
  const chess = new Chess();
  const pgns: { headers: Record<string, string>; pgn: string }[] = R.flow(
    opts.pgn,
    [
      R.partialRight(fs.readFileSync, ["utf8"]),
      R.trim,
      R.split("\n\n"),
      R.splitEvery(2),
      R.map(R.pipe(([headers, body]) => `${headers}\n\n${body}`, (pgn) => {
        chess.loadPgn(pgn);
        return { headers: chess.getHeaders(), pgn };
      })),
    ],
  );

  // Upload PGNs
  const results = [];
  const importGameWithRetries = (pgn: string) =>
    retryWithExponentialBackoff(
      () =>
        equine.gameImport({ body: { pgn } })
          .then((res) => {
            if (res.error) {
              if (typeof res.error === "string") throw new Error(res.error);
              else if (
                typeof res.error === "object" && "error" in res.error &&
                typeof res.error.error === "string"
              ) throw new Error(res.error.error);
              else throw new Error(`Unknown error from ${JSON.stringify(res)}`);
            } else if (!res.data || !res.data.id || !res.data.url) {
              throw new Error("No data");
            }
            return { id: res.data.id, url: res.data.url };
          }),
      {
        maxRetries: opts.maxRetries,
        rest: opts.rest,
      },
    );

  for await (const { pgn, headers } of pgns) {
    const game = await importGameWithRetries(pgn);
    await sleep(opts.rest);
    results.push({ pgn, headers, game });
  }

  // Format results
  const competitors: string[] = R.flow(pgns, [
    R.map(({ headers }) => [headers["White"], headers["Black"]]),
    R.flatten,
    R.uniq,
    R.sort(R.ascend((x: string) => x)),
  ]);
  if (competitors.length !== 2) {
    throw new Error("Expected exactly two competitors!");
  }
  const isCompetitorWin =
    (competitor: string) =>
    ({ headers }: { headers: Record<string, string> }) =>
      (headers.White === competitor && headers.Result === "1-0") ||
      (headers.Black === competitor && headers.Result === "0-1");

  const [competitor1, competitor2] = competitors;
  const competitor1Wins = pgns.filter(isCompetitorWin(competitor1)).length;
  const competitor2Wins = pgns.filter(isCompetitorWin(competitor2)).length;
  const draws = pgns.length - (competitor1Wins + competitor2Wins);

  const desiredHeaderKeys = [
    "Round",
    "White",
    "Black",
    "Result",
    "GameDuration",
    "PlyCount",
  ];
  const availableHeaderKeys: string[] = R.flow(pgns, [
    R.reduce(
      (acc: string[], { headers }) => [...Object.keys(headers), ...acc],
      [],
    ),
    R.uniq,
    R.filter((x: string) => desiredHeaderKeys.includes(x)),
  ]);
  const tableHeader = [...availableHeaderKeys, "url"];
  const table = [
    tableHeader,
    tableHeader.map((_) => "---"),
    ...R.flow(results, [
      R.sortWith([
        R.ascend((x) => x.headers.Round ?? ""),
        R.ascend((x) => x.headers.White ?? ""),
        R.descend((x) => x.headers.Result ?? ""),
      ]),
      R.map((
        { headers, game: { url } }: {
          headers: Record<string, string>;
          game: { url: string };
        },
      ) => [
        ...availableHeaderKeys.map((hk) => headers[hk] ?? "N/A"),
        url,
      ]),
    ]),
  ];
  const mdtable = tabulate(table, " | ");
  const md = `
# 🥊 ${opts.title}

## ${competitor1} - ${competitor2} Summary

- ${competitor1} wins: ${competitor1Wins}
- ${competitor2} wins: ${competitor2Wins}
- Draws: ${draws}

## Games

${mdtable}

`;
  process.stdout.write(md);
}

main();
