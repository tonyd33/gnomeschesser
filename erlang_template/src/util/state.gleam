//// State Monad
////

import gleam/list

pub type State(s, a) {
  State(run: fn(s) -> #(a, s))
}

pub fn map(state: State(s, a), f: fn(a) -> b) -> State(s, b) {
  State(run: fn(s) {
    let #(a, s_) = state.run(s)
    #(f(a), s_)
  })
}

pub fn pure(a: a) -> State(s, a) {
  State(run: fn(s) { #(a, s) })
}

pub fn return(a: a) -> State(s, a) {
  pure(a)
}

pub fn bind(state: State(s, a), f: fn(a) -> State(s, b)) -> State(s, b) {
  State(run: fn(s) {
    let #(a, s_) = state.run(s)
    let sb = f(a)
    sb.run(s_)
  })
}

pub const do = bind

/// `>>` operator. Run a state and discard its result and run the next
/// state.
///
/// It may have been smarter to call this `do` instead of calling `bind` `do``,
/// but we didn't do that and now `do` has a reserved meaning. Oh well.
///
pub fn discard(state: State(s, a), f: fn() -> State(s, b)) {
  State(run: fn(s) {
    let #(_, s_) = state.run(s)
    let sb = f()
    sb.run(s_)
  })
}

pub fn select(f: fn(s) -> a) -> State(s, a) {
  State(run: fn(s) { #(f(s), s) })
}

pub fn get_state() -> State(s, s) {
  State(run: fn(s) { #(s, s) })
}

pub fn put(s: s) -> State(s, Nil) {
  State(run: fn(_) { #(Nil, s) })
}

pub fn modify(f: fn(s) -> s) -> State(s, Nil) {
  use s <- do(get_state())
  put(f(s))
}

/// Like `list.fold_until`, but accumulates effects on the state monad
///
pub fn list_fold_until_s(
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
        list.Continue(initial_) -> list_fold_until_s(xs, initial_, fun)
      }
    }
  }
}

pub fn go(state: State(s, a), initial initial: s) {
  state.run(initial)
}
