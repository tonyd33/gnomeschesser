//// Reader Monad
////

import gleam/list

pub type Reader(r, a) {
  Reader(run: fn(r) -> #(a, r))
}

pub fn map(reader: Reader(r, a), f: fn(a) -> b) -> Reader(r, b) {
  Reader(run: fn(r) {
    let #(a, r_) = reader.run(r)
    #(f(a), r_)
  })
}

pub fn pure(a: a) -> Reader(r, a) {
  Reader(run: fn(r) { #(a, r) })
}

pub fn return(a: a) -> Reader(r, a) {
  pure(a)
}

pub fn bind(reader: Reader(r, a), f: fn(a) -> Reader(r, b)) -> Reader(r, b) {
  Reader(run: fn(r) {
    let #(a, r_) = reader.run(r)
    let rb = f(a)
    rb.run(r_)
  })
}

pub const do = bind

pub fn ask() -> Reader(r, r) {
  Reader(run: fn(r) { #(r, r) })
}

pub fn go(reader: Reader(r, a), initial: r) {
  reader.run(initial)
}

pub fn list_fold_until_s(
  over list: List(a),
  from initial: acc,
  with fun: fn(acc, a) -> Reader(s, list.ContinueOrStop(acc)),
) -> Reader(s, acc) {
  case list {
    [] -> return(initial)
    [x, ..xs] -> {
      use r <- bind(fun(initial, x))
      case r {
        list.Stop(initial_) -> return(initial_)
        list.Continue(initial_) -> list_fold_until_s(xs, initial_, fun)
      }
    }
  }
}

pub fn list_fold(
  over list: List(a),
  from initial: acc,
  with fun: fn(acc, a) -> Reader(s, acc),
) -> Reader(s, acc) {
  case list {
    [] -> return(initial)
    [x, ..xs] -> {
      use r <- bind(fun(initial, x))
      list_fold(xs, r, fun)
    }
  }
}
