// don't care about unnecessary async in handlers.
// deno-lint-ignore-file require-await
import fs from "node:fs";
import * as process from "node:process";
import { Chess } from "chess.js";
import { Result } from "./types.ts";

export function centerInTerminal(s: string): string {
  const width = process.stdout.columns || 80;
  return s.split("\n").map((line) =>
    " ".repeat(Math.max(0, Math.floor((width - line.length) / 2))) + line
  ).join("\n");
}

export type Command =
  | { _sig: "move"; move: string }
  | { _sig: "fen" }
  | { _sig: "load"; fen: string }
  | { _sig: "perft"; moves: number }
  | { _sig: "loadpgn"; pgn: string }
  | { _sig: "loadpgnfile"; pgnfile: string }
  | { _sig: "undo" }
  | { _sig: "moves" }
  | { _sig: "history" }
  | { _sig: "pgn" }
  | { _sig: "print" }
  | { _sig: "ask" }
  | { _sig: "set"; overload: "print" }
  | { _sig: "set"; overload: "key"; key: string }
  // deno-lint-ignore no-explicit-any
  | { _sig: "set"; overload: "modify"; key: string; value: any }
  | { _sig: "restart" }
  | { _sig: "quit" }
  | { _sig: "help" };

export type Setting =
  | { _sig: "autoask"; value: boolean }
  | { _sig: "robourl"; value: string };

export type Context = {
  chess: Chess;
  stop: boolean;
  settings: {
    [K in Setting["_sig"]]: Extract<Setting, { _sig: K }>["value"];
  };
};

export const settings: {
  [K in keyof Context["settings"]]: {
    summary?: string;
    default: Extract<Setting, { _sig: K }>["value"];
    parser: (
      args: string[],
    ) => Result<Extract<Setting, { _sig: K }>["value"], string>;
  };
} = {
  autoask: {
    summary: "automatically ask the robot for its move",
    default: false,
    parser: (args: string[]) => {
      if (args.length !== 1) return ["err", "expected one argument"];
      const modLowerCase = args[0].toLowerCase();
      if (modLowerCase === "true") {
        return ["ok", true];
      } else if (modLowerCase === "false") {
        return ["ok", false];
      } else {
        return ["err", "expected true or false"];
      }
    },
  },
  robourl: {
    summary: "url to contact robot",
    default: "http://localhost:8000/move",
    parser: (args: string[]) => {
      if (args.length !== 1) return ["err", "expected one argument"];
      return ["ok", args[0]];
    },
  },
};

export const defaultSettings: Context["settings"] = Object.fromEntries(
  Object.entries(settings)
    .map(([k, { default: _default }]) => [k, _default]),
) as Context["settings"];

const askRobot = async (ctx: Context): Promise<Context> => {
  const move = await fetch(
    ctx.settings.robourl,
    {
      method: "POST",
      body: JSON.stringify({
        fen: ctx.chess.fen(),
        turn: ctx.chess.turn() === "w" ? "white" : "black",
        failed_moves: [],
      }),
    },
  )
    .then((x) => x.text());

  ctx.chess.move(move);
  return ctx;
};

export const commands: {
  [K in Command["_sig"]]: {
    args?: string[];
    summary?: string;
    aliases?: string[];
    print?: boolean;
    parser: (
      args: string[],
    ) => Result<Omit<Extract<Command, { _sig: K }>, "_sig">, string>;
    handler: (
      context: Context,
      args: Omit<Extract<Command, { _sig: K }>, "_sig">,
    ) => Promise<Result<Context, string>>;
  };
} = {
  move: {
    args: ["san"],
    summary: "move a piece",
    aliases: ["", "m"],
    print: true,
    parser: (args) => {
      if (args.length !== 1) return ["err", "expected 1 argument"];
      return ["ok", { move: args[0] }];
    },
    handler: async (ctx, { move }) => {
      try {
        ctx.chess.move(move);
        if (ctx.settings.autoask) {
          console.log("robot is thinking...");
          return ["ok", await askRobot(ctx)];
        } else {
          return ["ok", ctx];
        }
      } catch (err) {
        const message = typeof err === "object" &&
            err != null && "message" in err &&
            typeof err.message === "string"
          ? err.message
          : "bad move, no more information";
        return ["err", message];
      }
    },
  },
  fen: {
    summary: "get fen",
    parser: (args) => {
      if (args.length !== 0) return ["err", "unexpected argument"];
      return ["ok", {}];
    },
    handler: async (ctx) => {
      console.log(ctx.chess.fen());
      return ["ok", ctx];
    },
  },
  perft: {
    summary: "get perft",
    args: ["moves"],
    parser: (args) => {
      if (args.length !== 1) return ["err", "expected argument"];
      const moves = parseInt(args[0]);
      if (isNaN(moves)) return ["err", "needed an int"];
      return ["ok", { moves }];
    },
    handler: async (ctx, { moves }) => {
      const start = Date.now();
      const perft = ctx.chess.perft(moves);
      const end = Date.now();
      console.log(perft);
      console.log(`Perft depth ${moves} in: ${end - start} ms`);
      console.log(
        `Perft depth ${moves} in: ${
          (perft * 1000 / (end - start)).toFixed(2)
        } nodes/second`,
      );
      return ["ok", ctx];
    },
  },
  load: {
    args: ["fen"],
    summary: "load a game",
    aliases: ["l"],
    print: true,
    // we don't have string quoting logic so args is always split lol
    parser: (args) =>
      args.length === 0 ? ["err", "need fen"] : ["ok", { fen: args.join(" ") }],
    handler: async (ctx, { fen }) => {
      ctx.chess.load(fen);
      return ["ok", ctx];
    },
  },
  loadpgn: {
    args: ["pgn"],
    summary: "load a pgn",
    aliases: ["lp"],
    print: true,
    parser: (args) =>
      args.length === 0 ? ["err", "need pgn"] : ["ok", { pgn: args.join(" ") }],
    handler: async (ctx, { pgn }) => {
      ctx.chess.loadPgn(pgn);
      return ["ok", ctx];
    },
  },
  loadpgnfile: {
    args: ["pgnfile"],
    summary: "load a pgn file",
    aliases: ["lpf"],
    print: true,
    parser: (args) =>
      args.length === 0
        ? ["err", "need pgn file"]
        : ["ok", { pgnfile: args.join(" ") }],
    handler: async (ctx, { pgnfile }) => {
      const pgn = await fs.promises.readFile(pgnfile, "utf8");
      ctx.chess.loadPgn(pgn);
      return ["ok", ctx];
    },
  },
  undo: {
    summary: "undo move",
    aliases: ["u"],
    print: true,
    parser: (args) => {
      if (args.length !== 0) return ["err", "unexpected argument"];
      return ["ok", {}];
    },
    handler: async (ctx) => {
      ctx.chess.undo();
      console.log(ctx.chess.ascii());
      return ["ok", ctx];
    },
  },
  moves: {
    summary: "print availables moves",
    aliases: ["ms", "mvs"],
    parser: (args) => {
      if (args.length !== 0) return ["err", "unexpected argument"];
      return ["ok", {}];
    },
    handler: async (ctx) => {
      console.log(ctx.chess.moves().join(", "));
      return ["ok", ctx];
    },
  },
  history: {
    summary: "print move history",
    aliases: ["hi", "hist"],
    parser: (args) => {
      if (args.length !== 0) return ["err", "unexpected argument"];
      return ["ok", {}];
    },
    handler: async (ctx) => {
      console.log(ctx.chess.history().join(","));
      return ["ok", ctx];
    },
  },
  pgn: {
    summary: "print pgn",
    parser: (args) => {
      if (args.length !== 0) return ["err", "unexpected argument"];
      return ["ok", {}];
    },
    handler: async (ctx) => {
      console.log(ctx.chess.pgn());
      return ["ok", ctx];
    },
  },
  print: {
    summary: "print game",
    aliases: ["p", "board"],
    print: true,
    parser: (args) => {
      if (args.length !== 0) return ["err", "unexpected argument"];
      return ["ok", {}];
    },
    // print deferred with print: true
    handler: async (ctx) => ["ok", ctx],
  },
  ask: {
    summary: "ask robot for move",
    aliases: ["a"],
    print: true,
    parser: (args) => {
      if (args.length !== 0) return ["err", "unexpected argument"];
      return ["ok", {}];
    },
    handler: async (ctx) => {
      console.log("robot is thinking...");
      return ["ok", await askRobot(ctx)];
    },
  },
  set: {
    args: ["[key]", "[value]"],
    summary: "manage settings",
    aliases: [],
    parser: (args) => {
      switch (args.length) {
        case 0:
          return ["ok", { overload: "print" }];
        case 1: {
          const [key] = args;
          return ["ok", { key, overload: "key" }];
        }
        case 2: {
          const [key, ...rest] = args;
          const settingsParser = settings[key as keyof Context["settings"]]
            ?.parser;
          if (!settingsParser) {
            return ["err", "unknown setting"];
          }
          const result = settingsParser(rest);
          if (result[0] !== "ok") return result;

          return ["ok", { overload: "modify", key, value: result[1] }];
        }
        default:
          return ["err", "expected 0-2 args"];
      }
    },
    handler: async (ctx, v) => {
      switch (v.overload) {
        case "modify": {
          // deno too dumb
          // deno-lint-ignore no-explicit-any
          const { key, value } = v as any;
          console.log(`${key}=${value}`);
          return ["ok", {
            ...ctx,
            settings: { ...ctx.settings, [key]: value },
          }];
        }
        case "key": {
          // deno-lint-ignore no-explicit-any
          const { key } = v as any;
          const value = ctx.settings[key as keyof Context["settings"]];
          console.log(`${key}=${value}`);
          return ["ok", ctx];
        }
        case "print": {
          console.log(
            Object.entries(ctx.settings).map(([key, value]) =>
              `${key}=${value}`
            ).join("\n"),
          );
          return ["ok", ctx];
        }
        default:
          return ["err", "how did we get here?"];
      }
    },
  },
  restart: {
    args: [],
    summary: "restart game",
    aliases: ["r", "rs", "reset"],
    parser: (args) => {
      if (args.length != 0) return ["err", "unexpected argument"];
      return ["ok", {}];
    },
    handler: async (ctx) => {
      ctx.chess.reset();
      return ["ok", ctx];
    },
  },
  quit: {
    args: [],
    summary: "quit",
    aliases: ["q", "exit"],
    parser: () => ["ok", {}],
    handler: async (ctx) => ["ok", { ...ctx, stop: true }],
  },
  help: {
    args: [],
    summary: "print commands",
    aliases: ["h", "?"],
    parser: () => ["ok", {}],
    handler: async (ctx) => {
      const colSep = "\t";
      const rows: {
        name: string;
        args: string;
        description: string;
        aliases: string;
      }[] = [
        // header row
        {
          name: "Name",
          args: "Arguments",
          description: "Description",
          aliases: "Aliases",
        },
        // special row
        {
          name: "^$",
          args: "san",
          description: "no name, just san",
          aliases: "",
        },
        ...Object.entries(commands).map(([k, v]) => ({
          name: k,
          args: (v.args ?? []).join(" "),
          description: v.summary ?? "",
          aliases: (v.aliases ?? []).join(", "),
        })),
      ];

      const maxWidths = rows.reduce((acc, row) => ({
        name: Math.max(row.name.length, acc.name),
        args: Math.max(row.args.length, acc.args),
        description: Math.max(row.description.length, acc.description),
        aliases: Math.max(row.aliases.length, acc.aliases),
      }), { name: 0, args: 0, description: 0, aliases: 0 });

      const commandsDescription = rows.map((row) =>
        [
          `${row.name.padEnd(maxWidths.name, " ")}`,
          `${row.args.padEnd(maxWidths.args, " ")}`,
          `${row.description.padEnd(maxWidths.description, " ")}`,
          `${row.aliases.padEnd(maxWidths.aliases, " ")}`,
        ].join(colSep)
      ).join("\n");

      console.log(commandsDescription);

      return ["ok", ctx];
    },
  },
};

export function resolveCommand(args: string[]) {
  const [commandStr, ...restArgs] = args;
  for (const [k, v] of Object.entries(commands)) {
    if (k === commandStr || (v.aliases ?? []).includes(commandStr)) {
      return { command: v, args: restArgs, fallback: false };
    }
  }

  // If nothing found, try to parse as move
  return { command: commands.move, args: [commandStr], fallback: true };
}
