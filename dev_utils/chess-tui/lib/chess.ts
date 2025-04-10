import { Chess, Color, PieceSymbol } from "chess.js";

const chessSymbols: Record<Color, Record<PieceSymbol, string>> = {
  // the actual color of this depends on terminal color though
  b: {
    p: "♟",
    n: "♞",
    b: "♝",
    r: "♜",
    q: "♛",
    k: "♚",
  },
  w: {
    p: "♙",
    n: "♘",
    b: "♗",
    r: "♖",
    q: "♕",
    k: "♔",
  },
};

export function chessUnicode(chess: Chess): string {
  let s = "   +------------------------+\n";
  const board = chess.board();
  for (let x = 0; x < board.length; x++) {
    const row = board[x];
    for (let y = 0; y < row.length; y++) {
      // display the rank
      if (y === 0) {
        s += " " + `${8 - x}` + " |";
      }
      const square = row[y];

      if (square) {
        s += " " + chessSymbols[square.color][square.type] + " ";
      } else {
        s += " . ";
      }

      if (y === 7) {
        s += "|\n";
      }
    }
  }
  s += "   +------------------------+\n";
  s += "     a  b  c  d  e  f  g  h";

  return s;
}
