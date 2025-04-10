import * as rl from "node:readline/promises";
import * as process from "node:process";
import { Chess } from "chess.js";
import {
  centerInTerminal,
  chessUnicode,
  Context,
  resolveCommand,
} from "./lib/index.ts";

async function main() {
  let ctx: Context = {
    chess: new Chess(),
    stop: false,
  };
  const iface = rl.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  console.log(
    `%c${centerInTerminal("chess-cli")}`,
    "color: green; font-weight: bold",
  );
  console.log(centerInTerminal(chessUnicode(ctx.chess)));
  console.log(`%c${centerInTerminal("type ? for commands")}`, "color: cyan");

  while (!ctx.stop) {
    const { command, args, fallback } = await iface.question("> ")
      .then((x) => x.split(" "))
      .then(resolveCommand);

    if (!command) {
      console.error("no such command");
      continue;
    }

    const { parser, handler, print } = command;
    try {
      const [parseStatus, parseVal] = parser(args);
      if (parseStatus != "ok") {
        console.error(`%c${parseVal}`, "color: red");
        continue;
      }

      // deno-lint-ignore no-explicit-any
      const [handlerStatus, handlerVal] = handler(ctx, parseVal as any);

      if (handlerStatus != "ok") {
        console.error(`%c${handlerVal}`, "color: red");
        if (fallback) {
          console.error("%cassumed implicit move command", "color: red");
          console.error("%ctype ? for commands", "color: red");
        }
        continue;
      } else {
        ctx = handlerVal;
        if (print) {
          console.log(
            " ".repeat(9) + (ctx.chess.turn() === "w" ? "White" : "Black") +
              " to move",
          );
          console.log(chessUnicode(ctx.chess));
        }
      }
    } catch (err) {
      console.error(err);
      continue;
    }
  }

  process.exit(0);
}

if (import.meta.main) {
  main();
}
