//// Blake is the shell of our engine. Control of the engine is governed
//// through messages to Blake.
////

import chess/actors/donovan
import chess/game.{type Game}
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option, None, Some}
import gleam/otp/actor

pub type Blake {
  Blake(game: Game, donovan_chan: Subject(donovan.Message))
}

pub type Message {
  Load(game: Game)
  Go(movetime: Option(Int))
  Stop
  Shutdown
}

pub fn start() {
  let assert Ok(blake) = actor.start(new(), handle_message)
  blake
}

fn new() {
  let assert Ok(game) = game.load_fen(game.start_fen)
  Blake(game:, donovan_chan: donovan.start())
}

fn handle_message(message: Message, blake: Blake) -> actor.Next(Message, Blake) {
  case message {
    Load(game) -> actor.continue(Blake(..blake, game:))
    Go(_) -> {
      process.send(
        blake.donovan_chan,
        donovan.Go(blake.game, process.new_subject()),
      )
      actor.continue(blake)
    }
    Stop -> {
      process.send(blake.donovan_chan, donovan.Stop)
      actor.continue(blake)
    }
    Shutdown -> actor.Stop(process.Normal)
  }
}
