//// At a wonderful intersection between purity and impurity, we have the
//// InterruptableState monad. Its key difference from the State monad is that
//// it allows for potential failures through "interrupts" and "checkpointing".
////
//// Note that the underlying mechanism actually works through polling, but
//// it's meant to be used in such a way that it simulates true interrupts.
////
//// It relies on periodic checks of an impure `interrupt` function that's
//// embedded into the state using the State monad.
////

import gleam/bool
import gleam/list
import util/state.{type State, State}

pub type InterruptableState(s, a) =
  State(#(fn(s) -> Bool, s), Result(a, Nil))

pub fn map(
  isa: InterruptableState(s, a),
  f: fn(a) -> b,
) -> InterruptableState(s, b) {
  use ra <- state.map(isa)
  case ra {
    Ok(a) -> Ok(f(a))
    Error(Nil) -> Error(Nil)
  }
}

pub fn bind(isa: InterruptableState(s, a), f: fn(a) -> InterruptableState(s, b)) {
  use ra <- state.do(isa)
  case ra {
    Ok(a) -> f(a)
    Error(Nil) -> state.return(Error(Nil))
  }
}

pub const do = bind

pub fn discard(
  state: InterruptableState(s, a),
  f: fn() -> InterruptableState(s, b),
) {
  use <- state.discard(state)
  f()
}

pub fn select(f: fn(s) -> a) -> InterruptableState(s, a) {
  use #(_, s) <- state.select
  Ok(f(s))
}

pub fn get_state() -> InterruptableState(s, s) {
  use #(_, s) <- state.select
  Ok(s)
}

pub fn put(s: s) -> InterruptableState(s, Nil) {
  use #(interrupt, _) <- state.do(state.get_state())
  use <- state.discard(state.put(#(interrupt, s)))
  state.return(Ok(Nil))
}

pub fn modify(f: fn(s) -> s) -> InterruptableState(s, Nil) {
  use #(_, s) <- state.do(state.get_state())
  put(f(s))
}

pub fn pure(a: a) -> InterruptableState(s, a) {
  state.pure(Ok(a))
}

pub const return = pure

/// Mark a routine as being interruptable:
/// ```gleam
/// use <- interruptable
/// // regular calculations here
/// ```
///
/// This does the interrupt check at the *start* of execution: It wouldn't
/// make much sense to do it after execution; the routine is already done!
///
pub fn interruptable(
  f: fn() -> InterruptableState(s, a),
) -> InterruptableState(s, a) {
  use #(interrupt, s) <- state.do(state.get_state())
  case interrupt(s) {
    True -> state.return(Error(Nil))
    False -> f()
  }
}

pub fn interruptable_when(
  when: Bool,
  f: fn() -> InterruptableState(s, a),
) -> InterruptableState(s, a) {
  use <- bool.guard(!when, f())

  use #(interrupt, s) <- state.do(state.get_state())
  case interrupt(s) {
    True -> state.return(Error(Nil))
    False -> f()
  }
}

/// Register a new interrupt check.
///
pub fn register(interrupt: fn() -> Bool) {
  use #(_, s) <- state.modify
  #(interrupt, s)
}

/// Transforms a `State(s, a)` into an `InterruptableState(s, a)`.
///
pub fn from_state(sa: State(s, a)) -> InterruptableState(s, a) {
  State(run: fn(x) {
    let #(interrupt, s) = x
    let #(a, s_) = sa.run(s)
    #(Ok(a), #(interrupt, s_))
  })
}

/// Create a checkpoint on a value such that if further execution leads to
/// an error, this result is used. Kind of like `result.lazy_unwrap`, but the
/// control flow is inversed.
///
pub fn checkpoint(a: a, f: fn() -> InterruptableState(s, a)) {
  use rb <- state.do(f())

  case rb {
    Ok(b) -> state.return(Ok(b))
    Error(Nil) -> state.return(Ok(a))
  }
}

/// Like `list.fold_until`, but accumulates effects on the interruptable
/// state monad
///
pub fn list_fold_until_s(
  over list: List(a),
  from initial: acc,
  with fun: fn(acc, a) -> InterruptableState(s, list.ContinueOrStop(acc)),
) -> InterruptableState(s, acc) {
  case list {
    [] -> return(initial)
    [x, ..xs] -> {
      use rr <- state.do(fun(initial, x))
      case rr {
        Ok(r) ->
          case r {
            list.Stop(initial_) -> return(initial_)
            list.Continue(initial_) -> list_fold_until_s(xs, initial_, fun)
          }
        Error(Nil) -> state.return(Error(Nil))
      }
    }
  }
}
