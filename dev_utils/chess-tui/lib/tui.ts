import * as process from "node:process";
import { Result } from "./result.ts";
import { Chess } from "chess.js";

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
  | { _sig: "undo" }
  | { _sig: "moves" }
  | { _sig: "history" }
  | { _sig: "pgn" }
  | { _sig: "print" }
  | { _sig: "restart" }
  | { _sig: "quit" }
  | { _sig: "help" };

export type Context = {
  chess: Chess;
  stop: boolean;
};

export const commands: {
  [K in Command["_sig"]]: {
    args?: string[];
    description?: string;
    aliases?: string[];
    print?: boolean;
    parser: (
      args: string[],
    ) => Result<Omit<Extract<Command, { _sig: K }>, "_sig">, string>;
    handler: (
      context: Context,
      args: Omit<Extract<Command, { _sig: K }>, "_sig">,
    ) => Result<Context, string>;
  };
} = {
  move: {
    args: ["san"],
    description: "move a piece",
    aliases: ["", "m"],
    print: true,
    parser: (args) => {
      if (args.length !== 1) return ["err", "expected 1 argument"];
      return ["ok", { move: args[0] }];
    },
    handler: (ctx, { move }) => {
      try {
        ctx.chess.move(move);
        return ["ok", ctx];
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
    description: "get fen",
    parser: (args) => {
      if (args.length !== 0) return ["err", "unexpected argument"];
      return ["ok", {}];
    },
    handler: (ctx) => {
      console.log(ctx.chess.fen());
      return ["ok", ctx];
    },
  },
  load: {
    args: ["fen"],
    description: "load a game",
    aliases: ["l"],
    print: true,
    // we don't have string quoting logic so args is always split lol
    parser: (args) =>
      args.length === 0 ? ["err", "need fen"] : ["ok", { fen: args.join(" ") }],
    handler: (ctx, { fen }) => {
      ctx.chess.load(fen);
      return ["ok", ctx];
    },
  },
  undo: {
    description: "undo move",
    aliases: ["u"],
    print: true,
    parser: (args) => {
      if (args.length !== 0) return ["err", "unexpected argument"];
      return ["ok", {}];
    },
    handler: (ctx) => {
      ctx.chess.undo();
      console.log(ctx.chess.ascii());
      return ["ok", ctx];
    },
  },
  moves: {
    description: "print availables moves",
    aliases: ["ms", "mvs"],
    parser: (args) => {
      if (args.length !== 0) return ["err", "unexpected argument"];
      return ["ok", {}];
    },
    handler: (ctx) => {
      console.log(ctx.chess.moves().join(", "));
      return ["ok", ctx];
    },
  },
  history: {
    description: "print move history",
    aliases: ["hi", "hist"],
    parser: (args) => {
      if (args.length !== 0) return ["err", "unexpected argument"];
      return ["ok", {}];
    },
    handler: (ctx) => {
      console.log(ctx.chess.history().join(","));
      return ["ok", ctx];
    },
  },
  pgn: {
    description: "print pgn",
    parser: (args) => {
      if (args.length !== 0) return ["err", "unexpected argument"];
      return ["ok", {}];
    },
    handler: (ctx) => {
      console.log(ctx.chess.pgn());
      return ["ok", ctx];
    },
  },
  print: {
    description: "print game",
    aliases: ["p", "board"],
    print: true,
    parser: (args) => {
      if (args.length !== 0) return ["err", "unexpected argument"];
      return ["ok", {}];
    },
    // print deferred with print: true
    handler: (ctx) => ["ok", ctx],
  },
  restart: {
    args: [],
    description: "restart game",
    aliases: ["r", "rs", "reset"],
    parser: (args) => {
      if (args.length != 0) return ["err", "unexpected argument"];
      return ["ok", {}];
    },
    handler: (ctx) => {
      ctx.chess.reset();
      return ["ok", ctx];
    },
  },
  quit: {
    args: [],
    description: "quit",
    aliases: ["q", "exit"],
    parser: () => ["ok", {}],
    handler: (ctx) => ["ok", { ...ctx, stop: true }],
  },
  help: {
    args: [],
    description: "print commands",
    aliases: ["h", "?"],
    parser: () => ["ok", {}],
    handler: (ctx) => {
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
          description: v.description ?? "",
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
