// deno-lint-ignore-file no-unreachable
import process from "node:process";
import readline from "node:readline";
import { Chess, Move } from "chess.js";

const serializeMove = (move: Move): string => `${move.before},${move.from},${move.to}`;

/**
 * Reads PGNs from stdin and prints the corresponding move table entries to
 * stdout.
 *
 * A table entry is a line that associates a FEN as the state of the game to a
 * SAN as the move that should be played.
 *
 * Table entries are constructed from a PGN by applying the sequences of moves
 * listed in the PGN, going through the history of the game, and associating
 * each game state to its corresponding move.
 */
async function main() {
  const chess = new Chess();

  const inputStream = process.stdin;
  const outputStream = process.stdout;
  const infoStream = process.stderr;
  const rl = readline.createInterface({ input: inputStream });

  let linesRead = 0;
  const iterator = rl[Symbol.asyncIterator]();
  const queue: string[] = [];
  const read = async (): Promise<IteratorResult<string, string>> => {
    if (queue.length === 0) {
      linesRead++;
      return iterator.next();
    }
    return { done: false, value: queue.pop() as string };
  };
  const unread = (l: string) => queue.push(l);

  let result;
  let lastPrintedLinesAt = 0;
  const printProgressEveryNLines = 100_000;

  outer:
  while (1) {
    if (linesRead - lastPrintedLinesAt >= printProgressEveryNLines) {
      infoStream.write(`Read ${linesRead} lines.\n`);
      lastPrintedLinesAt = linesRead;
    }

    const pgnLines = [];

    // Skip PGN header
    while (1) {
      result = await read();
      if (result.done) break outer;

      // Skip empty lines
      if (result.value.trim().length === 0) continue;
      if (!(/^\[.*\]$/).test(result.value)) {
        // Oops, read something that isn't a PGN header. Undo it
        unread(result.value);
        break;
      }
    }

    // Read PGN body
    while (1) {
      result = await read();
      if (result.done) break outer;
      if (result.value.trim().length === 0) continue;
      if ((/^\[.*\]$/).test(result.value)) {
        // Oops, read a PGN header. Undo it
        unread(result.value);
        break;
      }

      pgnLines.push(result.value);
    }

    const pgn = pgnLines.join("\n");
    chess.loadPgn(pgn);
    const decisions = chess.history({ verbose: true }).map(serializeMove);
    for (const decision of decisions) {
      outputStream.write(decision + "\n");
    }
    chess.reset();
  }
}

main();
