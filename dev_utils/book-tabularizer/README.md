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
...into a set of intermediate binary files in the [Polyglot format](http://hgm.nubati.net/book_format.html#key).
We can then use the Polyglot files to generate Gleam code like this:
```gleam
pub fn lookup_move(x) {
  case x of {
    0xDEADBEEF->[0x765,0x173]
    0xBAADF00D->[0x765]
    0xB0BABABE->[0x135,0x876]
    _->[]
  }
}
```

# Quick start

## Prerequisites

* C++ compiler
* Meson and Ninja

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
