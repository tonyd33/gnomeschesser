import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/otp/actor

pub type Message(k, v) {
  Clear
  Inc
  ManualTrim
  Size(reply_with: Subject(#(Int, Int, Int)))
  Get(key: k, reply_with: Subject(Result(Entry(v), Nil)))
  Insert(key: k, value: v)
}

/// A table to cache calculation results.
///
pub type Table(k, v) =
  dict.Dict(k, Entry(v))

pub type Entry(a) {
  Entry(value: a, mtime: Int, atime: Int, hits: Int)
}

/// When should we prune the table?
///
pub type TrimPolicy {
  Indiscriminately
  LargerThan(max_size: Int)
}

/// How should we prune the table?
///
pub type TrimMethod {
  ByRecency(max_recency: Int)
}

pub opaque type Auditor(k, v) {
  Auditor(n: Int, table: Table(k, v), hits: Int, misses: Int)
}

fn new() {
  Auditor(0, dict.new(), 0, 0)
}

fn trim(
  table: Table(k, v),
  how: TrimPolicy,
  method: TrimMethod,
  n: Int,
) -> Table(k, v) {
  // TODO: Finish
  case dict.size(table) >= 256_000 {
    True -> {
      // echo "pruning"
      let table = case method {
        ByRecency(max_recency:) ->
          table
          |> dict.filter(fn(_, entry) { n - entry.atime <= 128_000 })
      }
      table
    }
    False -> table
  }
}

const default_policy = LargerThan(32_000)

const default_method = ByRecency(16_000)

pub fn start() {
  let assert Ok(actor) = actor.start(new(), handle_message)
  actor
}

pub fn handle_message(
  message: Message(k, v),
  state: Auditor(k, v),
) -> actor.Next(Message(k, v), Auditor(k, v)) {
  case message {
    Clear -> new()
    Inc -> Auditor(..state, n: state.n + 1)
    Size(client) -> {
      process.send(client, #(dict.size(state.table), state.hits, state.misses))
      state
    }
    Get(key, client) -> {
      let Auditor(n:, table:, ..) = state
      let entry = dict.get(table, key)
      process.send(client, entry)
      case entry {
        Ok(entry) -> {
          Auditor(
            ..state,
            table: dict.insert(
              state.table,
              key,
              Entry(..entry, mtime: n, hits: entry.hits + 1),
            ),
            hits: state.hits + 1,
          )
        }
        Error(Nil) -> Auditor(..state, misses: state.misses + 1)
      }
    }
    Insert(key, value) -> {
      let Auditor(n:, table:, ..) = state
      let table =
        dict.insert(table, key, Entry(value:, mtime: n, atime: n, hits: 0))
        |> trim(default_policy, default_method, n)
      Auditor(..state, table:)
    }
    ManualTrim -> {
      let Auditor(n:, table:, ..) = state
      let table = trim(table, default_policy, default_method, n)
      Auditor(..state, table:)
    }
  }
  |> actor.continue
}
