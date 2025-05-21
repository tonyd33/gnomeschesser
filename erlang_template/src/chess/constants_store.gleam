import iv.{type Array}

pub type ConstantsStore {
  ConstantsStore(range_64: Array(Int))
}

pub fn new() -> ConstantsStore {
  ConstantsStore(range_64: iv.range(0, 63))
}
