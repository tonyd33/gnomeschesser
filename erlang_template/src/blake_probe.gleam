import chess/actors/blake
import chess/actors/donovan
import chess/game
import chess/move
import chess/uci
import gleam/erlang
import gleam/erlang/process
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import util/parser as p

pub fn main() {
  let blake_chan = blake.start()
  loop(blake_chan)
}

fn loop(blake_chan) {
  let engine_cmd = uci.engine_cmd()
  case erlang.get_line("") {
    Error(erlang.Eof) -> Nil
    Error(erlang.NoData) -> Nil
    Ok(line) -> {
      let continue = {
        let parsed = p.run(engine_cmd, line)
        case parsed {
          Ok(uci.EngCmdUCI) -> True
          Ok(uci.EngCmdQuit) -> {
            process.send(blake_chan, blake.Shutdown)
            False
          }
          Ok(uci.EngCmdUCINewGame) -> {
            let assert Ok(game) = game.load_fen(game.start_fen)
            process.send(blake_chan, blake.Load(game))
            True
          }
          Ok(uci.EngCmdIsReady) -> {
            True
          }
          Ok(uci.EngCmdPosition(moves:, position:)) -> {
            let start_game = case position {
              uci.PositionStartPos -> {
                let assert Ok(game) = game.load_fen(game.start_fen)
                game
              }
              uci.PositionFEN(fen) -> {
                let assert Ok(game) = game.load_fen(fen)
                game
              }
            }
            let assert Ok(game) = {
              use game, lan <- list.fold(moves, Ok(start_game))
              use game <- result.try(game)

              use move <- result.try(game.validate_move(
                move.from_lan(lan),
                game,
              ))
              Ok(game.apply(game, move))
            }

            process.send(blake_chan, blake.Load(game))
            True
          }
          Ok(uci.EngCmdStop) -> {
            process.send(blake_chan, blake.Stop)
            True
          }
          Ok(uci.EngCmdGo(params:)) -> {
            process.send(blake_chan, blake.Go(movetime: Some(5000)))
            True
          }
          // We ignore unrecognized commands
          _ -> True
        }
      }

      case continue {
        True -> loop(blake_chan)
        False -> Nil
      }
    }
  }
}
