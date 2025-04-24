// deno-lint-ignore-file require-await
import process from "node:process";
import {
  configure,
  info,
  score,
  UCIHandler,
  UCIInfo,
  UCIOption,
  UCIPosition,
} from "../lib/UCI/index.ts";
import { absurd } from "fp-ts/lib/function.js";
import { PassThrough, Transform, Writable } from "node:stream";
import fs from "node:fs";
import { Chess, Move } from "chess.js";

const startFen = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

class UCIProxyHandler implements UCIHandler {
  private name: string;
  private author: string;
  private advertiseOptions: UCIOption[];
  private robotUrl: string;

  private fen: string = startFen;
  private moves: string[] = [];

  private initialized = false;

  private sendInfo: (info: UCIInfo) => Promise<void>;
  private sendBestMove: (move: string, ponder?: undefined) => Promise<void>;

  private chess: Chess;

  private debugLog: (s: string) => void;

  constructor(
    {
      name,
      author,
      advertiseOptions,
      robotUrl,
      sendInfo,
      sendBestMove,
      debugLog,
    }: {
      name: string;
      author: string;
      advertiseOptions: UCIOption[];
      robotUrl: string;
      sendInfo: (info: UCIInfo) => Promise<void>;
      sendBestMove: (move: string, ponder?: undefined) => Promise<void>;
      debugLog?: (s: string) => void;
    },
  ) {
    this.name = name;
    this.author = author;
    this.advertiseOptions = advertiseOptions;
    this.robotUrl = robotUrl;
    this.sendInfo = sendInfo;
    this.sendBestMove = sendBestMove;
    this.chess = new Chess();
    this.debugLog = debugLog ?? (() => {});

    this.onInit = this.onInit.bind(this);
    this.onDebug = this.onDebug.bind(this);
    this.onSetOption = this.onSetOption.bind(this);
    this.onNewGame = this.onNewGame.bind(this);
    this.onLoadPosition = this.onLoadPosition.bind(this);
    this.onGo = this.onGo.bind(this);
    this.onStop = this.onStop.bind(this);
    this.onPonderHit = this.onPonderHit.bind(this);
    this.onQuit = this.onQuit.bind(this);
  }

  async onInit() {
    this.initialized = true;

    return {
      name: this.name,
      author: this.author,
      options: this.advertiseOptions,
    };
  }

  async onDebug() {}

  async onSetOption(name: string, value?: string) {}

  async onNewGame() {
    this.fen = startFen;
    this.moves = [];
  }

  async onLoadPosition(position: UCIPosition, moves: string[]) {
    switch (position.tag) {
      case "FEN": {
        this.fen = position.fen;
        break;
      }
      case "StartPos": {
        this.fen = startFen;
        break;
      }
      default:
        absurd(position);
    }
    this.moves = moves;
  }

  private loadBoard() {
    this.chess.load(this.fen);
    try {
      for (const lan of this.moves) {
        const { from, to, promotion } = this.lanToFromTo(lan);
        this.chess.move({ from, to, promotion });
      }
    } catch (err) {
      if (err instanceof Error) {
        this.debugLog(
          `Error applying moves: ${err.message}. All moves: ${
            JSON.stringify(this.moves)
          }. Available moves: ${this.chess.moves()}`,
        );
      } else {
        this.debugLog("Unknown error");
      }
    }
  }

  private lanToFromTo(lan: string) {
    const from = lan.slice(0, 2);
    const to = lan.slice(2, 4);
    const promotion = lan.slice(4) || undefined;
    return { from, to, promotion };
  }

  private sanToLan(san: string): string {
    this.loadBoard();
    const move = this.chess.move(san);
    this.chess.undo();

    const lan = `${move.from}${move.to}${move.promotion ?? ""}`;
    return lan;
  }

  async onGo() {
    this.loadBoard();

    this.debugLog("recv go. current chess board is:");
    this.debugLog(this.chess.ascii());
    this.debugLog(`fen: ${this.chess.fen()}`);

    const turn = this.fen.split(" ")[1] === "w" ? "white" : "black";
    this.debugLog("asking robot");
    const response = await fetch(this.robotUrl, {
      method: "POST",
      body: JSON.stringify({ fen: this.chess.fen(), failed_moves: [], turn }),
      headers: { "Content-Type": "application/json" },
    })
      .then((res) => res.text());
    this.debugLog(`robot said ${response}`);

    // uci only accepts long notation wtf!!!
    // So we have to convert it here using chess.js
    const lan = this.sanToLan(response);

    // TODO: Send real score
    this.sendInfo(info.score([score.centipawns(1)]));
    this.sendBestMove(lan);
  }

  async onStop() {}
  async onPonderHit() {}
  async onQuit() {
    process.exit(0);
  }
}

// jank below

const prefixChunk = (prefix: string) => (chunk: any) => {
  const now = new Date();
  const timestamp = `${now.getHours().toString().padStart(2, "0")}:${
    now.getMinutes().toString().padStart(2, "0")
  }.${now.getMilliseconds().toString().padStart(3, "0")}`;
  const s = chunk
    .toString()
    .split("\n")
    .filter((line: string) => line.length > 0)
    .map((line: string) => `${prefix}[${timestamp}] ${line}`).join("\n");
  if (s.length > 0 && s[s.length - 1] !== "\n") return s + "\n";
  return s;
};

const prefixTransformer = (prefix: string) =>
  new Transform({
    transform(chunk, _encoding, cb) {
      cb(null, prefixChunk(prefix)(chunk));
    },
  });

const teePrefixedStream = (
  ostream: NodeJS.WritableStream,
  dupstream: NodeJS.WritableStream,
  prefix: string,
) => {
  return new Writable({
    write(chunk, encoding, cb) {
      ostream.write(chunk, encoding);
      dupstream.write(prefixChunk(prefix)(chunk));
      cb();
    },
  });
};

const tapPrefixedStream = (
  ostream: NodeJS.ReadableStream,
  dupstream: NodeJS.WritableStream,
  prefix: string,
) => {
  const xform = prefixTransformer(prefix);
  ostream.pipe(xform).pipe(dupstream);
  return ostream;
};

const prefixStream = (
  ostream: NodeJS.WritableStream,
  prefix: string,
): Writable => {
  return new Writable({
    write(chunk, _encoding, callback) {
      ostream.write(prefixChunk(prefix)(chunk), callback);
    },
  });
};

const logStream = fs.createWriteStream("debug.log", { flags: "a" });

// Maybe a problem that they're all writing to the same stream, but let's ignore it :)
const stdoutTee = teePrefixedStream(process.stdout, logStream, "[>>>]: ");
const stderrTee = teePrefixedStream(process.stderr, logStream, "[>->]: ");
const stdinTap = tapPrefixedStream(process.stdin, logStream, "[<<<]: ");
const debugStream = prefixStream(logStream, "[>~>]: ");

const { listen, sendInfo, sendBestMove } = configure({
  input: stdinTap,
  output: stdoutTee,
  error: stderrTee,
  debug: debugStream,
});

const handler = new UCIProxyHandler({
  name: "Gnomes",
  author: "Gnomes",
  advertiseOptions: [],
  robotUrl: "http://localhost:8000/move",
  sendInfo,
  sendBestMove,
  debugLog: (s) => debugStream.write(s),
});

listen(handler);
