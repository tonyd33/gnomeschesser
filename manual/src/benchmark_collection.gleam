import chess/constants/zobrist
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
  list_array_map()
}

/// Findings:
/// Lists are slower, from about 1.5x to 2.05x slower on this data.
///
pub fn list_array_map() {
  let lst_10 = list.range(1, 10)
  let arr_10 = iv.from_list(lst_10)
  let dict_10 = dict.from_list(list.map(lst_10, fn(x) { #(x, x) }))

  let lst_100 = list.range(1, 100)
  let arr_100 = iv.from_list(lst_100)
  let dict_100 = dict.from_list(list.map(lst_100, fn(x) { #(x, x) }))

  let lst_1000 = list.range(1, 1000)
  let arr_1000 = iv.from_list(lst_1000)
  let dict_1000 = dict.from_list(list.map(lst_1000, fn(x) { #(x, x) }))

  benchmark.run(
    [
      benchmark.Function(
        label: "list map",
        callable: fn(test_data: #(List(Int), Array(Int), dict.Dict(Int, Int))) {
          fn() {
            test_data.0
            |> list.map(fn(x) { x * 2 })
            Nil
          }
        },
      ),
      benchmark.Function(
        label: "array map",
        callable: fn(test_data: #(List(Int), Array(Int), dict.Dict(Int, Int))) {
          fn() {
            test_data.1
            |> iv.map(fn(x) { x * 2 })
            Nil
          }
        },
      ),
      benchmark.Function(
        label: "dict map",
        callable: fn(test_data: #(List(Int), Array(Int), dict.Dict(Int, Int))) {
          fn() {
            test_data.2
            |> dict.map_values(fn(_, x) { x * 2 })
            Nil
          }
        },
      ),
    ],
    [
      benchmark.Data(label: "10", data: #(lst_10, arr_10, dict_10)),
      benchmark.Data(label: "100", data: #(lst_100, arr_100, dict_100)),
      benchmark.Data(label: "1000", data: #(lst_1000, arr_1000, dict_1000)),
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
  let dict_10 = dict.from_list(list.map(lst_10, fn(x) { #(x, x) }))

  let lst_100 = list.range(1, 100)
  let arr_100 = iv.from_list(lst_100)
  let dict_100 = dict.from_list(list.map(lst_100, fn(x) { #(x, x) }))

  let lst_1000 = list.range(1, 1000)
  let arr_1000 = iv.from_list(lst_1000)
  let dict_1000 = dict.from_list(list.map(lst_1000, fn(x) { #(x, x) }))

  benchmark.run(
    [
      benchmark.Function(
        label: "list filter",
        callable: fn(test_data: #(List(Int), Array(Int), dict.Dict(Int, Int))) {
          fn() {
            test_data.0
            |> list.filter(fn(x) { x % 2 == 0 })
            Nil
          }
        },
      ),
      benchmark.Function(
        label: "array filter",
        callable: fn(test_data: #(List(Int), Array(Int), dict.Dict(Int, Int))) {
          fn() {
            test_data.1
            |> iv.filter(fn(x) { x % 2 == 0 })
            Nil
          }
        },
      ),
      benchmark.Function(
        label: "dict filter",
        callable: fn(test_data: #(List(Int), Array(Int), dict.Dict(Int, Int))) {
          fn() {
            test_data.2
            |> dict.filter(fn(_, x) { x % 2 == 0 })
            Nil
          }
        },
      ),
    ],
    [
      benchmark.Data(label: "10", data: #(lst_10, arr_10, dict_10)),
      benchmark.Data(label: "100", data: #(lst_100, arr_100, dict_100)),
      benchmark.Data(label: "1000", data: #(lst_1000, arr_1000, dict_1000)),
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

pub fn fast_flatten(lists: List(List(a))) -> List(a) {
  fast_flatten_loop(lists, [])
}

fn fast_flatten_loop(lists: List(List(a)), acc: List(a)) -> List(a) {
  case lists {
    [] -> acc
    [list, ..further_lists] ->
      fast_flatten_loop(further_lists, list.append(list, acc))
  }
}

type DiffList(a) =
  fn(List(a)) -> List(a)

fn to_diff_list(l: List(a)) -> DiffList(a) {
  fn(x) { list.append(l, x) }
}

fn to_list(f: DiffList(a)) -> List(a) {
  f([])
}

fn diff_list_empty() {
  fn(x) { x }
}

fn diff_list_append(f, g) {
  fn(xs) { f(g(xs)) }
}

/// Findings:
/// Array flat maps are slower than list flat maps, ranging from about
/// 8.5x to 10.75x slower on this data. However, if exiting iv arrays into
/// lists, it's slightly faster than list flat maps.
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
      benchmark.Function(
        label: "array flatmap -> list",
        callable: fn(test_data: #(List(Int), Array(Int))) {
          fn() {
            test_data.1
            |> iv.fold([], fn(acc, x) { [list.repeat(x, 5), ..acc] })
            |> fast_flatten
            Nil
          }
        },
      ),
      benchmark.Function(
        label: "array flatmap -> difference lists",
        callable: fn(test_data: #(List(Int), Array(Int))) {
          fn() {
            test_data.1
            |> iv.fold(diff_list_empty(), fn(acc, x) {
              diff_list_append(acc, to_diff_list(list.repeat(x, 5)))
            })
            |> to_list()
            Nil
          }
        },
      ),
      benchmark.Function(
        label: "array flatmap -> yielder -> list",
        callable: fn(test_data: #(List(Int), Array(Int))) {
          fn() {
            test_data.1
            |> iv.fold(yielder.empty(), fn(acc, x) {
              yielder.append(acc, yielder.repeat(x) |> yielder.take(5))
            })
            |> yielder.to_list
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

pub fn tuple_array_lookup() {
  let arr =
    list.range(0, 780)
    |> list.fold(iv.new(), fn(arr, x) { iv.append(arr, zobrist.get_hash(x)) })

  benchmark.run(
    [
      benchmark.Function(
        label: "tuple lookup (fn)",
        callable: fn(test_data: List(Int)) {
          fn() {
            test_data
            |> list.map(zobrist.get_hash)
            Nil
          }
        },
      ),
      benchmark.Function(
        label: "tuple lookup (hack)",
        callable: fn(test_data: List(Int)) {
          fn() {
            test_data
            |> list.map(zobrist.get_hash_hack)
            Nil
          }
        },
      ),
      benchmark.Function(
        label: "array lookup",
        callable: fn(test_data: List(Int)) {
          fn() {
            test_data
            |> list.map(iv.get(arr, _))
            Nil
          }
        },
      ),
    ],
    [benchmark.Data(label: "indices", data: list.range(0, 780))],
  )
}

pub fn array_take() {
  let arr =
    list.range(1, 1000)
    |> iv.from_list

  benchmark.run(
    [
      benchmark.Function(label: "take", callable: fn(test_data: Int) {
        fn() {
          iv.take_first(arr, test_data)
          Nil
        }
      }),
    ],
    [
      benchmark.Data(label: "10", data: 10),
      benchmark.Data(label: "100", data: 100),
    ],
  )
}
