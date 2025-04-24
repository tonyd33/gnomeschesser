import { parseUCIEngineCmd } from "./Parser.ts";
import {
  guiCmd,
  id,
  UCIEngineCommand,
  UCIGUICommand,
  UCIId,
  UCIInfo,
  UCIOption,
  UCIPosition,
  UCIScore,
} from "./Types.ts";
import readline from "node:readline/promises";
import * as E from "fp-ts/lib/Either.js";
import * as TE from "fp-ts/lib/TaskEither.js";
import * as T from "fp-ts/lib/Task.js";
import { absurd, flow, pipe } from "fp-ts/lib/function.js";
import * as A from "fp-ts/lib/Array.js";

/**
 * We only use this type internally. We expose a higher-level interface for
 * clients to work with UCI
 */
type _UCIHandler = (_: UCIEngineCommand) => Promise<UCIGUICommand[]>;

export interface UCIHandler {
  /**
   * When we receive a "uci" command to initiate the protocol, the engine
   * must identify itself and advertise its options to the client.
   */
  onInit: () => Promise<
    { name: string; author: string; options: UCIOption[] }
  >;
  /** */
  onDebug: () => Promise<void>;
  /** The client has set an option. */
  onSetOption: (name: string, value?: string) => Promise<void>;
  /** The client intends to start a new game. */
  onNewGame: () => Promise<void>;
  onLoadPosition: (position: UCIPosition, moves: string[]) => Promise<void>;
  onGo: () => Promise<void>;
  onStop: () => Promise<void>;
  onPonderHit: () => Promise<void>;
  onQuit: () => Promise<void>;
}

type Tokens = string[];

const always = <A>(a: A) => () => a;

const wrapStrErr = <A, B>(f: (a: A) => Promise<B>) => (a: A) =>
  TE.tryCatch<string, B>(
    () => f(a),
    (err) => {
      if (err instanceof Error) return `Unexpected error: ${err.message}`;
      else return `Unknown error`;
    },
  );

const withLine = (s: string) => {
  if (s.length === 0 || s[s.length - 1] === "\n") return s;
  else return s + "\n";
};

const tokenizeId = (id: UCIId): Tokens => {
  switch (id.tag) {
    case "Name":
      return ["name", id.name];
    case "Author":
      return ["author", id.author];
    default:
      return absurd(id);
  }
};

const tokenizeScore = (score: UCIScore): Tokens => {
  switch (score.tag) {
    case "Centipawns":
      return ["cp", `${score.n}`];
    case "Mate":
      return ["mate", `${score.n}`];
    case "Lowerbound":
      return ["lowerbound"];
    case "Upperbound":
      return ["upperbound"];
    default:
      return absurd(score);
  }
};

const tokenizeInfo = (info: UCIInfo): Tokens => {
  switch (info.tag) {
    case "Depth":
      return ["depth", `${info.depth}`];
    case "SelDepth":
      return ["seldepth", `${info.depth}`];
    case "Time":
      return ["time", `${info.time}`];
    case "Nodes":
      return ["nodes", `${info.nodes}`];
    case "Preview":
      return ["pv", ...info.moves];
    case "MultiPreview":
      return ["multipv", `${info.n}`];
    case "Score":
      return ["score", ...info.params.flatMap(tokenizeScore)];
    case "CurrMove":
      return ["currmove", info.move];
    case "CurrMoveNumber":
      return ["currmovenumber", `${info.n}`];
    case "HashFull":
      return ["hashfull", `${info.n}`];
    case "NodesPerSecond":
      return ["nps", `${info.n}`];
    case "TableBaseHits":
      return ["tbhits", `${info.n}`];
    case "ShredderBaseHits":
      return ["sbhits", `${info.n}`];
    case "CPULoad":
      return ["cpuload", `${info.n}`];
    case "String":
      return ["string", `${info.s}`];
    case "Refutation":
      return ["refutation", ...info.moves];
    case "CurrLine":
      return ["currline", `${info.cpunr}`, ...info.moves];
    default:
      return absurd(info);
  }
};

const tokenizeOption = (
  option: UCIOption,
): Tokens => [
  "name",
  option.name,
  "type",
  option.type.toLowerCase(),
  ...(option.default ? ["default", option.default] : []),
  ...(option.min ? ["min", option.min] : []),
  ...(option.max ? ["max", option.max] : []),
  ...(option.var ? ["var", option.var] : []),
];

const tokenizeGUICmd = (guiCmd: UCIGUICommand): Tokens => {
  switch (guiCmd.tag) {
    case "Id":
      return ["id", ...tokenizeId(guiCmd.id)];
    case "UCIOk":
      return ["uciok"];
    case "ReadyOk":
      return ["readyok"];
    case "BestMove":
      return [
        "bestmove",
        guiCmd.move,
        ...(guiCmd.ponder ? [guiCmd.ponder] : []),
      ];
    case "CopyProtection":
      return ["copyprotection", guiCmd.status];
    case "Registration":
      return ["registration", guiCmd.status];
    case "Info":
      return ["info", ...guiCmd.params.flatMap(tokenizeInfo)];
    case "Option":
      return ["option", ...tokenizeOption(guiCmd.option)];
    default:
      return absurd(guiCmd);
  }
};

const serializeTokens = (tokens: Tokens): string => tokens.join(" ");
const serializeGUICmd = flow(tokenizeGUICmd, serializeTokens);

// TODO: Implement copyprotection and registration
const protocolHandler = (
  {
    onInit,
    onSetOption,
    onNewGame,
    onLoadPosition,
    onGo,
    onStop,
    onPonderHit,
    onQuit,
  }: UCIHandler,
): _UCIHandler => {
  return async (engineCmd: UCIEngineCommand): Promise<UCIGUICommand[]> => {
    switch (engineCmd.tag) {
      case "UCI":
        return onInit().then((
          { name, author, options },
        ) => [
          guiCmd.id(id.name(name)),
          guiCmd.id(id.author(author)),
          ...options.map(guiCmd.option),
          guiCmd.uciOk,
        ]);
      case "Debug":
        return [];
      // Respond to the ping command immediately.
      case "IsReady":
        return [guiCmd.readyOk];
      case "SetOption":
        return onSetOption(engineCmd.name, engineCmd.value).then(() => []);
      case "Register":
        return [];
      case "UCINewGame":
        return onNewGame().then(() => []);
      case "Position":
        return onLoadPosition(engineCmd.position, engineCmd.moves).then(
          () => [],
        );
      case "Go":
        return onGo().then(() => []);
      case "Stop":
        return onStop().then(() => []);
      case "Ponderhit":
        return onPonderHit().then(() => []);
      case "Quit":
        return onQuit().then(() => []);
    }
  };
};

export const configure = (
  { input, output, error, debug }: {
    input: NodeJS.ReadableStream;
    output: NodeJS.WritableStream;
    /**
     * A separate, additional stream to write errors or other metadata to, to
     * prevent polluting the main stream.
     */
    error?: NodeJS.WritableStream;
    debug?: NodeJS.WritableStream;
  },
) => {
  const writeP = (s: string) =>
    new Promise<void>((resolve) => output.write(withLine(s), () => resolve()));
  const writeErrorP = (s: string) =>
    new Promise<void>((resolve) =>
      error ? error.write(withLine(s), () => resolve()) : resolve
    );
  const writeDebugP = (s: string) =>
    new Promise<void>((resolve) =>
      debug ? debug.write(withLine(s), () => resolve()) : resolve
    );
  const writeT = flow(writeP, always);
  const writeErrorT = flow(writeErrorP, always);
  const informResult = (x: E.Either<string, string>) =>
    pipe(x, E.map(writeT), E.getOrElse(writeErrorT));

  const sendInfo = flow(
    (info: UCIInfo) => guiCmd.info([info]),
    serializeGUICmd,
    writeP,
  );
  const sendBestMove = flow(guiCmd.bestMove, serializeGUICmd, writeP);

  return {
    listen: (handler: UCIHandler) => {
      const iface = readline.createInterface({
        input,
        output,
        terminal: false,
      });
      const lowLevelHandler = pipe(protocolHandler(handler), wrapStrErr);
      const handleLine = async (line: string) => {
        const processLine = pipe(
          line,
          TE.of,
          TE.chain(flow(parseUCIEngineCmd, TE.fromEither)),
          TE.chain(lowLevelHandler),
          TE.map((cmds) => cmds.map(serializeGUICmd).join("\n")),
          T.tap(informResult),
        );
        await processLine();
      };

      iface.on("line", handleLine);
    },
    sendInfo,
    sendBestMove,
  };
};
