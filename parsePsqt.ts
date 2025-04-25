import fs from "node:fs/promises";

const file = await fs.readFile("./psqt.txt", "utf8");

const formatPieceName = (s: string): { player: string; symbol: string } => {
  const [playerS, symbolS] = s.split("_");
  let player: string;
  switch (playerS) {
    case "W":
      player = "player.White";
      break;
    case "B":
      player = "player.Black";
      break;
    default:
      throw Error("unknown player");
  }
  let symbol = symbolS.toLowerCase();
  symbol = `${symbol[0].toUpperCase()}${symbol.slice(1)}`;
  symbol = `piece.${symbol}`;

  return { player, symbol };
};

const templateTableCell = (
  { score, piece, square }: { score: number; piece: string; square: string },
) => {
  const { player, symbol } = formatPieceName(piece);
  return `piece.Piece(${player}, ${symbol}), square.${square} -> ${score}`;
};

const generateGleamFnFromData = (data: {
  score: number;
  piece: string;
  square: string;
  mgeg: string;
}[]) => {
  let s = "fn get_psq_score(piece: piece.Piece, square: square.Square) {\n";
  s += "  case piece, square {\n";
  for (const cell of data) {
    s += "   ";
    s += templateTableCell(cell);
    s += "\n";
  }
  s += "  }\n";
  s += "}";

  return s;
};

const data = file
  .split("\n")
  .map((line) => {
    const [l, r] = line.split(" = ");
    const score = parseInt(r, 10);
    const [piece, square, mgeg] = l.split("@");
    return { score, piece, square, mgeg };
  });

const egData = data.filter(({ mgeg }) => mgeg === "EG");
const mgData = data.filter(({ mgeg }) => mgeg === "MG");

console.log(generateGleamFnFromData(mgData));
