//// Yapper is meant to be used as an IO thread to plumb messages into the
//// outside world.
////

import gleam/erlang/process.{type Selector, type Subject}
import gleam/function.{identity}
import gleam/io
import gleam/list
import gleam/order.{Eq, Gt, Lt}
import gleam/string

pub type Level {
  Debug
  Info
  Warn
  Err
}

pub opaque type Yap {
  Yap(msg: String, level: Level)
}

pub type Transformer =
  fn(String) -> String

pub type Message {
  SetLevel(level: Level)
  TransformLevel(level: Level, transformer: Transformer)
  Yaps(Yap)
  Die
}

pub fn start(level) {
  let out_chan = process.new_subject()
  process.start(
    fn() {
      let chan = process.new_subject()
      let yap_chan = process.new_subject()

      let selector =
        process.new_selector()
        |> process.selecting(chan, identity)
        |> process.selecting(yap_chan, fn(x) { Yaps(x) })
      process.send(out_chan, #(chan, yap_chan))

      let yapper =
        Yapper(level, yap_chan, identity, identity, identity, identity)
      loop(yapper, selector)
    },
    True,
  )
  process.receive_forever(out_chan)
}

pub fn debug(s: String) {
  Yap(s, Debug)
}

pub fn info(s: String) {
  Yap(s, Info)
}

pub fn warn(s: String) {
  Yap(s, Warn)
}

pub fn err(s: String) {
  Yap(s, Err)
}

pub fn prefix_debug() -> Transformer {
  // Yeah, this is inefficient, but without a proper pretty printing algorithm,
  // it's the best we got
  fn(x) {
    x
    |> string.split("\n")
    |> list.map(fn(l) { "[debug] " <> l })
    |> string.join("\n")
  }
}

pub fn prefix_info() -> Transformer {
  fn(x) {
    x
    |> string.split("\n")
    |> list.map(fn(l) { "[info] " <> l })
    |> string.join("\n")
  }
}

pub fn prefix_warn() -> Transformer {
  fn(x) {
    x
    |> string.split("\n")
    |> list.map(fn(l) { "[warn] " <> l })
    |> string.join("\n")
  }
}

pub fn prefix_err() -> Transformer {
  fn(x) {
    x
    |> string.split("\n")
    |> list.map(fn(l) { "[err] " <> l })
    |> string.join("\n")
  }
}

type Yapper {
  Yapper(
    level: Level,
    yap_chan: Subject(Yap),
    debug_transformer: Transformer,
    info_transformer: Transformer,
    warn_transformer: Transformer,
    err_transformer: Transformer,
  )
}

fn loop(yapper, recv_selector) {
  let m = case process.select_forever(recv_selector) {
    SetLevel(level) -> Ok(Yapper(..yapper, level:))
    TransformLevel(level, transformer) -> {
      case level {
        Debug -> Ok(Yapper(..yapper, debug_transformer: transformer))
        Info -> Ok(Yapper(..yapper, info_transformer: transformer))
        Warn -> Ok(Yapper(..yapper, warn_transformer: transformer))
        Err -> Ok(Yapper(..yapper, err_transformer: transformer))
      }
    }
    Yaps(Yap(msg, level)) -> {
      case compare_yap(level, yapper.level) {
        Gt | Eq -> {
          case level {
            Debug -> msg |> yapper.debug_transformer |> io.println_error
            Info -> msg |> yapper.info_transformer |> io.println
            Warn -> msg |> yapper.warn_transformer |> io.println_error
            Err -> msg |> yapper.err_transformer |> io.println_error
          }
        }
        _ -> Nil
      }
      Ok(yapper)
    }
    Die -> Error(Nil)
  }

  case m {
    Ok(new_yapper) -> loop(new_yapper, recv_selector)
    Error(Nil) -> Nil
  }
}

fn compare_yap(l1, l2) {
  case l1, l2 {
    Debug, Debug -> Eq
    Debug, Err -> Lt
    Debug, Info -> Lt
    Debug, Warn -> Lt
    Info, Debug -> Gt
    Info, Info -> Eq
    Info, Warn -> Lt
    Info, Err -> Lt
    Warn, Debug -> Gt
    Warn, Info -> Gt
    Warn, Warn -> Eq
    Warn, Err -> Lt
    Err, Err -> Eq
    Err, Debug -> Gt
    Err, Info -> Gt
    Err, Warn -> Gt
  }
}
