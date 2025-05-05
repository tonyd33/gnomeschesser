//// State Monad
////

import gleam/list

pub type State(s, a) {
  State(run: fn(s) -> #(a, s))
}

/// Equivalent to Haskell `fmap`
///
pub fn fmap(state: State(s, a), f: fn(a) -> b) -> State(s, b) {
  State(run: fn(s) {
    let #(a, s_) = state.run(s)
    #(f(a), s_)
  })
}

/// pure
///
pub fn pure(a: a) -> State(s, a) {
  State(run: fn(s) { #(a, s) })
}

pub fn return(a: a) -> State(s, a) {
  pure(a)
}

/// Equivalent to Haskell `>>=`
///
pub fn bind(state: State(s, a), f: fn(a) -> State(s, b)) -> State(s, b) {
  State(run: fn(s) {
    let #(a, s_) = state.run(s)
    let sb = f(a)
    sb.run(s_)
  })
}

pub const do = bind

pub fn gets(f: fn(s) -> a) -> State(s, a) {
  State(run: fn(s) { #(f(s), s) })
}

pub fn get() -> State(s, s) {
  State(run: fn(s) { #(s, s) })
}

/// Like `list.fold_until`, but accumulates effects on the state monad
///
pub fn fold_until_s(
  over list: List(a),
  from initial: acc,
  with fun: fn(acc, a) -> State(s, list.ContinueOrStop(acc)),
) -> State(s, acc) {
  case list {
    [] -> return(initial)
    [x, ..xs] -> {
      use r <- bind(fun(initial, x))
      case r {
        list.Stop(initial_) -> return(initial_)
        list.Continue(initial_) -> fold_until_s(xs, initial_, fun)
      }
    }
  }
}

pub fn go(state: State(s, a), initial: s) {
  state.run(initial)
}
