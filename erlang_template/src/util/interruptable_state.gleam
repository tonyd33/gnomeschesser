import gleam/list
import util/state.{type State, State}

pub type InterruptableState(s, a) =
  State(s, Result(a, Nil))

pub fn interruptable(
  interrupt: fn() -> Bool,
  fs: fn() -> InterruptableState(s, a),
) -> InterruptableState(s, a) {
  case interrupt() {
    True -> state.return(Error(Nil))
    False -> {
      use v <- state.map(fs())
      v
    }
  }
}

pub fn into(sa: State(s, a)) -> InterruptableState(s, a) {
  use a <- state.map(sa)
  Ok(a)
}

pub fn do(isa: InterruptableState(s, a), f: fn(a) -> InterruptableState(s, b)) {
  use ra <- state.do(isa)
  case ra {
    Ok(a) -> f(a)
    Error(Nil) -> state.return(Error(Nil))
  }
}

pub fn discard(
  state: InterruptableState(s, a),
  f: fn() -> InterruptableState(s, b),
) {
  use <- state.discard(state)
  f()
}

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

pub fn return(a: a) -> InterruptableState(s, a) {
  state.return(Ok(a))
}

pub fn do_checkpoint(
  isa: InterruptableState(s, a),
  f: fn(a) -> InterruptableState(s, a),
) -> InterruptableState(s, a) {
  use ra <- state.do(isa)
  checkpoint(ra, f)
}

pub fn checkpoint(ra: Result(a, Nil), f: fn(a) -> InterruptableState(s, a)) {
  case ra {
    Ok(a) -> {
      use rb <- state.do(f(a))

      case rb {
        Ok(b) -> state.return(Ok(b))
        Error(Nil) -> state.return(Ok(a))
      }
    }
    Error(_) -> state.return(Error(Nil))
  }
}

/// Like `list.fold_until`, but accumulates effects on the state monad
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
