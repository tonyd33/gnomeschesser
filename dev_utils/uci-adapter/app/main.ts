// deno-lint-ignore-file require-await
import process from "node:process";
import {
  configure,
  info,
  UCIHandler,
  UCIInfo,
  UCIOption,
  UCIPosition,
} from "../lib/UCI/index.ts";
import { absurd } from "fp-ts/lib/function.js";

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

  constructor(
    { name, author, advertiseOptions, robotUrl, sendInfo, sendBestMove }: {
      name: string;
      author: string;
      advertiseOptions: UCIOption[];
      robotUrl: string;
      sendInfo: (info: UCIInfo) => Promise<void>;
      sendBestMove: (move: string, ponder?: undefined) => Promise<void>;
    },
  ) {
    this.name = name;
    this.author = author;
    this.advertiseOptions = advertiseOptions;
    this.robotUrl = robotUrl;
    this.sendInfo = sendInfo;
    this.sendBestMove = sendBestMove;

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

  async onNewGame() {}

  async onLoadPosition(position: UCIPosition, moves: string[]) {
    this.moves = moves;
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
  }

  async onGo() {
    if (!this.initialized) return;

    const turn = this.fen.split(" ")[1] === "w" ? "white" : "black";
    this.sendInfo(info.str("Asking robot"));
    const response = await fetch(this.robotUrl, {
      method: "POST",
      body: JSON.stringify({ fen: this.fen, failed_moves: [], turn }),
      headers: { "Content-Type": "application/json" },
    })
      .then((res) => res.text());
    this.sendBestMove(response);
  }

  async onStop() {}
  async onPonderHit() {}
  async onQuit() {
    process.exit(0);
  }
}

const { listen, sendInfo, sendBestMove } = configure({
  input: process.stdin,
  output: process.stdout,
  error: process.stderr,
});

const handler = new UCIProxyHandler({
  name: "Gnomes",
  author: "Gnomes",
  advertiseOptions: [],
  robotUrl: "http://localhost:8000/move",
  sendInfo,
  sendBestMove,
});

listen(handler);
