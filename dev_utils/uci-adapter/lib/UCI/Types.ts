export type UCIRegister =
  | { tag: "Later" }
  | { tag: "Name"; name: string }
  | { tag: "Code"; code: string };

export type UCIPosition =
  | { tag: "FEN"; fen: string }
  | { tag: "StartPos" };

export type UCIId =
  | { tag: "Name"; name: string }
  | { tag: "Author"; author: string };

export type UCIScore =
  | { tag: "Centipawns"; n: number }
  | { tag: "Mate"; n: number }
  | { tag: "Lowerbound" }
  | { tag: "Upperbound" };

export type UCIInfo =
  | { tag: "Depth"; depth: number }
  | { tag: "SelDepth"; depth: number }
  | { tag: "Time"; time: number }
  | { tag: "Nodes"; nodes: number }
  | { tag: "Preview"; moves: string[] } // pv
  | { tag: "MultiPreview"; n: number } // multipv
  | { tag: "Score"; parameters: UCIScore[] }
  | { tag: "CurrMove"; move: string }
  | { tag: "CurrMoveNumber"; n: number }
  | { tag: "HashFull"; n: number }
  | { tag: "NodesPerSecond"; n: number } // npx
  | { tag: "TableBaseHits"; n: number }
  | { tag: "ShredderBaseHits"; n: number }
  | { tag: "CPULoad"; n: number }
  | { tag: "String"; s: string }
  | { tag: "Refutation"; moves: string[] }
  | { tag: "CurrLine"; cpunr: number; moves: string[] };

export type UCIGoParameter =
  | { tag: "SearchMoves"; moves: string[] }
  | { tag: "Ponder" }
  | { tag: "WTime"; time: number }
  | { tag: "BTime"; time: number }
  | { tag: "WInc"; time: number }
  | { tag: "BInc"; time: number }
  | { tag: "MovesToGo"; n: number }
  | { tag: "Depth"; depth: number }
  | { tag: "Nodes"; nodes: number }
  | { tag: "Mate"; n: number }
  | { tag: "MoveTime"; time: number }
  | { tag: "Infinite" };

export type UCIEngineCommand =
  | { tag: "UCI" }
  | { tag: "Debug"; on?: boolean }
  | { tag: "IsReady" }
  | { tag: "SetOption"; name: string; value?: string }
  | { tag: "Register"; register: UCIRegister }
  | { tag: "UCINewGame" }
  | { tag: "Position"; position: UCIPosition; moves: string[] }
  | { tag: "Go"; parameters: UCIGoParameter[] }
  | { tag: "Stop" }
  | { tag: "Ponderhit" }
  | { tag: "Quit" };

export type UCIGUICommand =
  | { tag: "Id"; id: UCIId }
  | { tag: "UCIOk" }
  | { tag: "ReadyOk" }
  | { tag: "BestMove"; move: string; ponder?: string }
  | { tag: "CopyProtection" }
  | { tag: "Registration" }
  | { tag: "Info"; params: UCIInfo[] }
  | {
    tag: "Option";
    name: string;
    type: "Check" | "Spin" | "Combo" | "Button" | "String";
    default_?: string;
    min?: string;
    max?: string;
    var_?: string;
  };
