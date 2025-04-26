# Book Tabularizer

Tooling to convert chess move books into a table-like format to load into a
gleam program. Turns a file of PGNs like this:
```
[Event "?"]
[Site "?"]
[Date "2013.11.02"]
[Round "1"]
[White "Stockfish"]
[Black "Stockfish"]
[Result "1/2-1/2"]
[Eco "A07"]

1. Nf3 d5 2. g3 c6 3. Bg2 Nf6 4. d3 Bg4 5. h3 Bh5 6. b3 e6 7. Bb2 Qa5+ 8.
Qd2 Qxd2+ 1/2-1/2
```
...into a set of intermediate files like this:
```
rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1,Nf3
rnbqkbnr/pppppppp/8/8/8/5N2/PPPPPPPP/RNBQKB1R b KQkq - 1 1,d5
rnbqkbnr/ppp1pppp/8/3p4/8/5N2/PPPPPPPP/RNBQKB1R w KQkq - 0 2,g3
...
```
...and then into a file like this:
```
"1k1r1bnr/pppqp1pp/2n2p2/3p4/1P1P2b1/2P2NP1/P2NPPBP/R1BQ1RK1 b - - 2 8" -> ["Bh3","e5","h5"]
"1k1r1bnr/pppqp1pp/2n2p2/3p4/1P1P2b1/2P2NP1/P2NPPBP/R1BQK2R w KQ - 0 8" -> ["Nb3"]
"1k1r1bnr/pppqp1pp/2n2p2/3p4/1P1P2b1/2P2NP1/P3PPBP/RNBQ1RK1 w - - 1 8" -> ["Nbd2","a4"]
"1k1r1bnr/pppqp1pp/2n2p2/3p4/3P1Bb1/2P1PN2/PP1NBPPP/R2QK2R w KQ - 1 8" -> ["b4"]
```

# Quick start

## Prerequisites

* Ensure you have a C compiler that can be run with `cc`
* Ensure you have deno and GNU make installed

## Get books

* Download chess books from e.g. [Stockfish's library](https://github.com/official-stockfish/books).
* Unzip desired PGN archives into a directory, e.g. `/path/to/books`

## Tabularize

```sh
mkdir tables
./batch-tabularize.sh \
    --books-dir /path/to/books \
    --tables-dir tables \
    --combined-table tables/combined.tbl \
    --grouped-file cases.txt
```

You should be left with a table in `tables/combined.tbl` and a file that can
easily by turned into a gleam function in `cases.txt`.
