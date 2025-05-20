import fs from "node:fs";
import process from "node:process";
import { Chess } from "chess.js";

const chess = new Chess();

const file = process.argv[1];
const lines = await fs
  .promises
  .readFile(file, "utf8")
  .then((f) => f.trim().split("\n"));

const output = lines
  .map((line) => {
    const matches = line.match(/^(\S+ \S+ \S+ \S+).*$/);
    if (!matches) throw new Error();

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
        if (!matches) throw new Error();
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
            console.log("unknown key", key, value);
            return [key, value];
        }
      });
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
        if (!move) throw new Error();
        return `${move.from}${move.to}`;
      };
      const bmlans = bms.map(san2lan);
      const amlans = ams ? ams.map(san2lan) : ams;
      return { ...tc, bms: bmlans, ams: amlans };
    },
  );

console.log(JSON.stringify(output, null, 2));
