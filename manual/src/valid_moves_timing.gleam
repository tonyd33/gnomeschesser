import chess/constants_store
import bencher
import chess/game
import gleam/dict

pub fn main() {
  let store = constants_store.new()
  // positions are from
  // https://www.chessprogramming.org/Perft_Results
  let assert Ok(starting) = game.load_fen(game.start_fen)
  let assert Ok(kiwipete) =
    game.load_fen(
      "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
    )
  let assert Ok(position3) =
    game.load_fen("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")

  let assert Ok(midgame_1) =
    game.load_fen(
      "rnb1kb1r/pp3ppp/2ppp3/4P1N1/3P4/3B1P2/PPP4P/RN1QK2n b Qkq - 1 10",
    )
  bencher.run(dict.from_list([#("game.valid_moves", game.valid_moves(_, store))]), [
    bencher.Warmup(2),
    bencher.Parallel(2),
    bencher.Inputs(
      [
        #("starting pos", starting),
        #("kiwipete", kiwipete),
        #("position3", position3),
        #("midgame_1", midgame_1),
      ]
      |> dict.from_list,
    ),
  ])
}
