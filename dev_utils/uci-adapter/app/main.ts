import process from "node:process";
import readline from "node:readline/promises";
import { parseUCIEngineCmd } from "../lib/UCI/Parser.ts";

const iface = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

type UCIState =
  /**
   * State when the program first starts. We will be waiting to accept "uci"
   * from stdin before doing anything else.
   */
  | { tag: "Boot" }
  /**
   * We have booted from the UCI command and are now awaiting further
   * instructions.
   */
  | {
    tag: "Waiting";
    /**  */
    fen?: string;
  };

while (1) {
  const cmd = await iface.question("").then(parseUCIEngineCmd);
  console.log(cmd)
}
