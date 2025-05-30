import gleam/order.{type Order}

/// Sort by `f1`, falling back to `f2` in case of ties in `f1`.
/// This function is lazy in `f2`.
///
pub fn or(f1: fn(a, a) -> Order, f2: fn(a, a) -> Order) -> fn(a, a) -> Order {
  fn(x, y) { order.lazy_break_tie(f1(x, y), fn() { f2(x, y) }) }
}
