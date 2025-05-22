import gleam/bool
import gleam/int
import gleam/io
import gleam/list
import iv.{type Array}

pub type ConstantsStore {
  ConstantsStore(
    range_64: Array(Int),
    ox88_squares: Array(Int),
    baked_moves: BakedMoves,
  )
}

const ox88_squares = [
  112, 96, 80, 64, 48, 32, 16, 0, 113, 97, 81, 65, 49, 33, 17, 1, 114, 98, 82,
  66, 50, 34, 18, 2, 115, 99, 83, 67, 51, 35, 19, 3, 116, 100, 84, 68, 52, 36,
  20, 4, 117, 101, 85, 69, 53, 37, 21, 5, 118, 102, 86, 70, 54, 38, 22, 6, 119,
  103, 87, 71, 55, 39, 23, 7,
]

pub fn new() -> ConstantsStore {
  ConstantsStore(
    range_64: iv.range(0, 63),
    ox88_squares: iv.from_list(ox88_squares),
    baked_moves: new_baked_moves(),
  )
}

pub type BakedMoves {
  BakedMoves(
    // knight[0x88 square][direction]
    knight: Array(List(Int)),
    // cardinals[0x88 square][direction][depth]
    cardinals: Array(List(List(Int))),
    // ordinals[0x88 square][direction][depth]
    ordinals: Array(List(List(Int))),
    cardinal_ordinals: Array(List(List(Int))),
  )
}

fn is_valid(ox88: Int) -> Bool {
  0 == int.bitwise_and(ox88, int.bitwise_not(0x77))
}

fn new_baked_moves() {
  BakedMoves(
    knight: {
      use from_square <- iv.map(iv.range(0, 0x77))
      use offset <- list.filter_map([-18, -33, -31, -14, 18, 33, 31, 14])
      let to_square = from_square + offset
      use <- bool.guard(!is_valid(from_square), Error(Nil))
      use <- bool.guard(!is_valid(to_square), Error(Nil))
      Ok(to_square)
    },
    cardinals: {
      use from_square <- iv.map(iv.range(0, 0x77))
      use direction <- list.map([-16, 1, 16, -1])
      use depth <- list.filter_map(list.range(1, 8))
      let offset = direction * depth
      let to_square = from_square + offset
      use <- bool.guard(!is_valid(from_square), Error(Nil))
      use <- bool.guard(!is_valid(to_square), Error(Nil))
      Ok(to_square)
    },
    ordinals: {
      use from_square <- iv.map(iv.range(0, 0x77))
      use direction <- list.map([-17, -15, 17, 15])
      use depth <- list.filter_map(list.range(1, 8))
      let offset = direction * depth
      let to_square = from_square + offset
      use <- bool.guard(!is_valid(from_square), Error(Nil))
      use <- bool.guard(!is_valid(to_square), Error(Nil))
      Ok(to_square)
    },
    cardinal_ordinals: {
      use from_square <- iv.map(iv.range(0, 0x77))
      use direction <- list.map([-17, -16, -15, 1, 17, 16, 15, -1])
      use depth <- list.filter_map(list.range(1, 8))
      let offset = direction * depth
      let to_square = from_square + offset
      use <- bool.guard(!is_valid(from_square), Error(Nil))
      use <- bool.guard(!is_valid(to_square), Error(Nil))
      Ok(to_square)
    },
  )
}
