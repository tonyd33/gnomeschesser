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
      describe: "time (ms) to rest between uploads",
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
  for await (const { pgn, headers } of pgns) {
    const game = await equine.gameImport({ body: { pgn } })
      .then((res) => {
        if (res.error) {
          if (typeof res.error === "string") throw new Error(res.error);
          else throw new Error("Unknown error");
        } else if (!res.data || !res.data.id || !res.data.url) {
          throw new Error("No data");
        }
        return { id: res.data.id, url: res.data.url };
      });
    await sleep(1000);
    results.push({ pgn, headers, game });
  }

  // Format results
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
      R.sortBy(({ headers }) => headers.Round),
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
# 🥊 SPRT Results

${mdtable}

`;
  process.stdout.write(md);
}

main();
