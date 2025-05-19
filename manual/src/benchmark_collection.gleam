import chess/game
import chess/piece
import chess/player
import chess/square
import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import glychee/benchmark
import glychee/configuration
import iv.{type Array}
import prng/random
import util/yielder

pub fn main() {
  configuration.initialize()
  configuration.set_pair(configuration.Warmup, 2)
  configuration.set_pair(configuration.Parallel, 4)
  configuration.set_pair(configuration.MemoryTime, 0)
  configuration.set_pair(configuration.ReductionTime, 0)
  configuration.set_pair(configuration.Time, 5)

  // Change this as you need
  list_array_flat_map()
}

/// Findings:
/// Lists are slower, from about 1.5x to 2.05x slower on this data.
///
pub fn list_array_map() {
  let lst_10 = list.range(1, 10)
  let arr_10 = iv.from_list(lst_10)

  let lst_100 = list.range(1, 100)
  let arr_100 = iv.from_list(lst_100)

  let lst_1000 = list.range(1, 1000)
  let arr_1000 = iv.from_list(lst_1000)

  benchmark.run(
    [
      benchmark.Function(
        label: "list map",
        callable: fn(test_data: #(List(Int), Array(Int))) {
          fn() {
            test_data.0
            |> list.map(fn(x) { x * 2 })
            Nil
          }
        },
      ),
      benchmark.Function(
        label: "array map",
        callable: fn(test_data: #(List(Int), Array(Int))) {
          fn() {
            test_data.1
            |> iv.map(fn(x) { x * 2 })
            Nil
          }
        },
      ),
    ],
    [
      benchmark.Data(label: "10", data: #(lst_10, arr_10)),
      benchmark.Data(label: "100", data: #(lst_100, arr_100)),
      benchmark.Data(label: "1000", data: #(lst_1000, arr_1000)),
    ],
  )
}

/// Findings:
/// Arrays are slower than lists at filtering, ranging from 1.4x to 2.6x
/// slower on this data.
///
pub fn list_array_filter() {
  let lst_10 = list.range(1, 10)
  let arr_10 = iv.from_list(lst_10)

  let lst_100 = list.range(1, 100)
  let arr_100 = iv.from_list(lst_100)

  let lst_1000 = list.range(1, 1000)
  let arr_1000 = iv.from_list(lst_1000)

  benchmark.run(
    [
      benchmark.Function(
        label: "list filter",
        callable: fn(test_data: #(List(Int), Array(Int))) {
          fn() {
            test_data.0
            |> list.filter(fn(x) { x % 2 == 0 })
            Nil
          }
        },
      ),
      benchmark.Function(
        label: "array filter",
        callable: fn(test_data: #(List(Int), Array(Int))) {
          fn() {
            test_data.1
            |> iv.filter(fn(x) { x % 2 == 0 })
            Nil
          }
        },
      ),
    ],
    [
      benchmark.Data(label: "10", data: #(lst_10, arr_10)),
      benchmark.Data(label: "100", data: #(lst_100, arr_100)),
      benchmark.Data(label: "1000", data: #(lst_1000, arr_1000)),
    ],
  )
}

/// Findings:
/// As expected, fold is much faster on arrays. List speeds range from being
/// about 1.15x to 2x slower than arrays on this data.
///
pub fn list_array_fold() {
  let lst_10 = list.range(1, 10)
  let arr_10 = iv.from_list(lst_10)

  let lst_100 = list.range(1, 100)
  let arr_100 = iv.from_list(lst_100)

  let lst_1000 = list.range(1, 1000)
  let arr_1000 = iv.from_list(lst_1000)

  benchmark.run(
    [
      benchmark.Function(
        label: "list fold",
        callable: fn(test_data: #(List(Int), Array(Int))) {
          fn() {
            test_data.0
            |> list.fold(0, fn(x, y) { x + y })
            Nil
          }
        },
      ),
      benchmark.Function(
        label: "array fold",
        callable: fn(test_data: #(List(Int), Array(Int))) {
          fn() {
            test_data.1
            |> iv.fold(0, fn(x, y) { x + y })
            Nil
          }
        },
      ),
    ],
    [
      benchmark.Data(label: "10", data: #(lst_10, arr_10)),
      benchmark.Data(label: "100", data: #(lst_100, arr_100)),
      benchmark.Data(label: "1000", data: #(lst_1000, arr_1000)),
    ],
  )
}

/// Findings:
/// Array find is generally slower, and gets worse as the size of the
/// collection grows, ranging from 1.05x to 1.50x slower on this data
///
pub fn list_array_find() {
  let lst_10 = list.range(1, 10)
  let arr_10 = iv.from_list(lst_10)

  let lst_100 = list.range(1, 100)
  let arr_100 = iv.from_list(lst_100)

  let lst_1000 = list.range(1, 1000)
  let arr_1000 = iv.from_list(lst_1000)

  benchmark.run(
    [
      benchmark.Function(
        label: "list find",
        callable: fn(test_data: #(List(Int), Array(Int), random.Generator(Int))) {
          fn() {
            let needle = random.random_sample(test_data.2)
            test_data.0
            |> list.find(fn(x) { x == needle })
          }
        },
      ),
      benchmark.Function(
        label: "array find",
        callable: fn(test_data: #(List(Int), Array(Int), random.Generator(Int))) {
          fn() {
            let needle = random.random_sample(test_data.2)
            test_data.1
            |> iv.find(fn(x) { x == needle })
          }
        },
      ),
    ],
    [
      benchmark.Data(label: "10", data: #(lst_10, arr_10, random.int(1, 10))),
      benchmark.Data(label: "100", data: #(lst_100, arr_100, random.int(1, 100))),
      benchmark.Data(label: "1000", data: #(
        lst_1000,
        arr_1000,
        random.int(1, 1000),
      )),
    ],
  )
}

/// Findings:
/// Array flat maps are slower than list flat maps, ranging from about
/// 8.5x to 10.75x slower on this data.
///
pub fn list_array_flat_map() {
  let lst_10 = list.range(1, 10)
  let arr_10 = iv.from_list(lst_10)

  let lst_100 = list.range(1, 100)
  let arr_100 = iv.from_list(lst_100)

  let lst_1000 = list.range(1, 1000)
  let arr_1000 = iv.from_list(lst_1000)

  benchmark.run(
    [
      benchmark.Function(
        label: "list flatmap",
        callable: fn(test_data: #(List(Int), Array(Int))) {
          fn() {
            test_data.0
            |> list.flat_map(fn(x) { list.repeat(x, 5) })
            Nil
          }
        },
      ),
      benchmark.Function(
        label: "array flatmap",
        callable: fn(test_data: #(List(Int), Array(Int))) {
          fn() {
            test_data.1
            |> iv.flat_map(fn(x) { iv.repeat(x, 5) })
            Nil
          }
        },
      ),
    ],
    [
      benchmark.Data(label: "10", data: #(lst_10, arr_10)),
      benchmark.Data(label: "100", data: #(lst_100, arr_100)),
      benchmark.Data(label: "1000", data: #(lst_1000, arr_1000)),
    ],
  )
}

pub fn list_array_creation() {
  benchmark.run(
    [
      benchmark.Function(label: "list range", callable: fn(test_data) {
        fn() {
          list.range(1, test_data)
          Nil
        }
      }),
      benchmark.Function(label: "array range", callable: fn(test_data) {
        fn() {
          iv.range(1, test_data)
          Nil
        }
      }),
    ],
    [
      benchmark.Data(label: "10", data: 10),
      benchmark.Data(label: "100", data: 100),
      benchmark.Data(label: "1000", data: 1000),
    ],
  )
}

/// Findings on the 100 dataset:
/// list -> yielder  16.48 M
/// array -> yielder 11.11 M
/// array -> list     1.50 M
/// list -> array     0.39 M
///
pub fn list_array_conversion() {
  let lst_10 = list.range(1, 10)
  let arr_10 = iv.from_list(lst_10)

  let lst_100 = list.range(1, 100)
  let arr_100 = iv.from_list(lst_100)

  let lst_1000 = list.range(1, 1000)
  let arr_1000 = iv.from_list(lst_1000)

  benchmark.run(
    [
      benchmark.Function(
        label: "list -> array",
        callable: fn(test_data: #(List(Int), Array(Int))) {
          fn() {
            test_data.0
            |> iv.from_list
            Nil
          }
        },
      ),
      benchmark.Function(
        label: "array -> list",
        callable: fn(test_data: #(List(Int), Array(Int))) {
          fn() {
            test_data.1
            |> iv.to_list
            Nil
          }
        },
      ),
      benchmark.Function(
        label: "list -> yielder",
        callable: fn(test_data: #(List(Int), Array(Int))) {
          fn() {
            test_data.0
            |> yielder.from_list
            Nil
          }
        },
      ),
      benchmark.Function(
        label: "array -> yielder",
        callable: fn(test_data: #(List(Int), Array(Int))) {
          fn() {
            test_data.1
            |> iv.to_yielder
            Nil
          }
        },
      ),
    ],
    [
      benchmark.Data(label: "10", data: #(lst_10, arr_10)),
      benchmark.Data(label: "100", data: #(lst_100, arr_100)),
      benchmark.Data(label: "1000", data: #(lst_1000, arr_1000)),
    ],
  )
}

/// Findings:
/// Dict lookup is about 1.3x slower than array lookup.
///
pub fn list_dict_lookup() {
  let assert Ok(game) = game.load_fen(game.start_fen)
  let board = game.board(game)
  let arr =
    list.fold(dict.to_list(board), iv.repeat(None, 0x88), fn(arr, x) {
      let assert Ok(arr) = iv.set(arr, x.0, Some(x.1))
      arr
    })
  let ox88_gen = random.int(1, 0x88)

  benchmark.run(
    [
      benchmark.Function(
        label: "dict lookup",
        callable: fn(
          test_data: #(
            dict.Dict(square.Square, piece.Piece),
            Array(Option(piece.Piece)),
          ),
        ) {
          fn() {
            let needle = random.random_sample(ox88_gen)
            let _ =
              test_data.0
              |> dict.get(needle)
            Nil
          }
        },
      ),
      benchmark.Function(
        label: "array lookup",
        callable: fn(
          test_data: #(
            dict.Dict(square.Square, piece.Piece),
            Array(Option(piece.Piece)),
          ),
        ) {
          fn() {
            let needle = random.random_sample(ox88_gen)
            let _ =
              test_data.1
              |> iv.get(needle)
            Nil
          }
        },
      ),
    ],
    [benchmark.Data(label: "board", data: #(board, arr))],
  )
}

/// Findings:
/// Dict modify is about 2.2x slower than array modify.
///
pub fn list_dict_modify() {
  let assert Ok(game) = game.load_fen(game.start_fen)
  let board = game.board(game)
  let arr =
    list.fold(dict.to_list(board), iv.repeat(None, 0x88), fn(arr, x) {
      let assert Ok(arr) = iv.set(arr, x.0, Some(x.1))
      arr
    })
  let ox88_gen = random.int(1, 0x88)
  let pawn = piece.Piece(player.White, piece.Pawn)

  benchmark.run(
    [
      benchmark.Function(
        label: "dict modify",
        callable: fn(
          test_data: #(
            dict.Dict(square.Square, piece.Piece),
            Array(Option(piece.Piece)),
          ),
        ) {
          fn() {
            let needle = random.random_sample(ox88_gen)
            let _ =
              test_data.0
              |> dict.insert(needle, pawn)
            Nil
          }
        },
      ),
      benchmark.Function(
        label: "array modify",
        callable: fn(
          test_data: #(
            dict.Dict(square.Square, piece.Piece),
            Array(Option(piece.Piece)),
          ),
        ) {
          fn() {
            let needle = random.random_sample(ox88_gen)
            let _ =
              test_data.1
              |> iv.set(needle, Some(pawn))
            Nil
          }
        },
      ),
    ],
    [benchmark.Data(label: "board", data: #(board, arr))],
  )
}
