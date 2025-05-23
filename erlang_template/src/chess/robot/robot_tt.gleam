import chess/search/transposition
import gleam/dict
import gleam/erlang/process.{type Subject}
import gleam/otp/actor

pub type Message {
  Clear
  Get(key: Int, reply_with: Subject(Result(transposition.Entry, Nil)))
  Insert(key: Int, entry: transposition.Entry)
}

pub fn handle_message(
  message: Message,
  table: transposition.Table,
) -> actor.Next(Message, transposition.Table) {
  case message {
    Clear -> actor.continue(transposition.new())
    Get(key, client) -> {
      process.send(client, dict.get(table, key))
      actor.continue(table)
    }
    Insert(key, entry) -> actor.continue(dict.insert(table, key, entry))
  }
}
