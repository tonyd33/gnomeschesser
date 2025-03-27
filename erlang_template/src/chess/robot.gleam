import chess/game.{type Game}
import chess/move
import gleam/erlang/process.{type Subject}

pub type UpdateMessage {
  NewFen(fen: String)
}

pub type ResponseMessage {
  Timeout
  NewBestMove(move: move.SAN)
}

pub fn run(
  mailbox: Subject(UpdateMessage),
  response_mailbox: Subject(ResponseMessage),
) {
  let assert Ok(initial_state) =
    game.load_fen("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
  main_loop(initial_state, mailbox, response_mailbox)
}

fn main_loop(
  state: Game,
  mailbox: Subject(UpdateMessage),
  response_mailbox: Subject(ResponseMessage),
) {
  let message = process.receive(mailbox, 0)
  let new_state = case message {
    Ok(NewFen(_fen)) -> {
      state
      // update game and state and stuff
    }
    Error(Nil) -> {
      let new_best_move: move.SAN = "Nc6"
      let new_state = state
      // perform another step of the calculations

      process.send(response_mailbox, NewBestMove(new_best_move))
      new_state
    }
  }

  main_loop(new_state, mailbox, response_mailbox)
}
