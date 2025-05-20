import fs from "node:fs";
import process from "node:process";
import { Chess } from "chess.js";
import yargs from "yargs";
import { hideBin } from "yargs/helpers";

async function main() {
  const opts = await yargs()
    .scriptName("bratko-kopec")
    .usage("$0 [args]")
    .option("epd", {
      type: "string",
      demandOption: true,
      describe: "epd path",
    })
    .parse(hideBin(process.argv));

  const chess = new Chess();

  const lines = await fs
    .promises
    .readFile(opts.epd, "utf8")
    .then((f) => f.trim().split("\n"));

  const output = lines
    .map((line) => {
      const matches = line.match(/^(\S+ \S+ \S+ \S+).*$/);
      if (!matches) throw new Error(`failed to match line '${line}'`);

      const fenish = matches[1];
      const rest = line.slice(fenish.length);
      const fen = `${fenish} 0 1`;
      const fieldsArr = rest
        .trim()
        .split(";")
        .map((field) => field.trim())
        .filter((field) => field !== "")
        .map((field) => {
          const matches = field.match(/^([a-zA-Z0-9]+) (.*)$/);
          if (!matches) throw new Error(`failed to match field '${field}'`);
          const [_, key, value] = matches;
          return [key, value];
        })
        .map((x) => {
          const [key, value] = x;
          switch (key) {
            case "bm":
              return ["bms", value.split(" ")];
            // avoid moves
            case "am":
              return ["ams", value.split(" ")];
            case "id":
              return [key, value.replaceAll('"', "")];
            case "c0":
              return ["comment", value.replaceAll('"', "")];
            default:
              console.warn("unknown key", key, value);
              return null;
          }
        })
        .filter(x => x !== null);
      const fields = Object.fromEntries(fieldsArr);

      return { fen, ...fields };
    })
    .map(
      (
        tc: {
          fen: string;
          bms: string[];
          id: string;
          comment?: string;
          ams?: string[];
        },
      ) => {
        const { fen, bms, ams } = tc;
        chess.load(fen);
        const moves = chess.moves({ verbose: true });
        const san2lan = (san: string) => {
          const move = moves.find((move) => move.san === san);
          if (!move) throw new Error(`no move '${san}' for fen '${fen}'`);
          return `${move.from}${move.to}`;
        };
        const bmlans = bms.map(san2lan);
        const amlans = ams ? ams.map(san2lan) : ams;
        return { ...tc, bms: bmlans, ams: amlans };
      },
    );

  console.log(JSON.stringify(output, null, 2));
}

await main();
