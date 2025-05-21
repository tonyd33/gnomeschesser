import bencher
import chess/bitboard
import chess/game
import chess/piece
import chess/square
import chess/util/perft
import gleam/dict
import gleam/int
import gleam/list

type Arguments {
  Arguments(
    board: dict.Dict(square.Square, piece.Piece),
    bitboard: bitboard.GameBitboard,
  )
}

pub fn empty_at(bitboard, square: square.Square) -> Bool {
  let square = bitboard.from_square(square)
  0 == int.bitwise_and(square, bitboard.get_bitboard_all(bitboard))
}

pub fn main() {
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

  let squares = square.get_squares()

  bencher.run(
    dict.from_list([
      #("bitboard", fn(args: Arguments) {
        squares
        |> list.map(empty_at(args.bitboard, _))
        Nil
      }),
      #("bitboard raw", fn(args: Arguments) {
        squares
        |> list.map(fn(square) {
          let rank = int.bitwise_shift_right(square, 4)
          let file = int.bitwise_and(square, 0x0f)

          let bit = int.bitwise_shift_left(1, rank * 8 + file)
          {
            args.bitboard.white_pawns
            |> int.bitwise_or(args.bitboard.white_rooks)
            |> int.bitwise_or(args.bitboard.white_knights)
            |> int.bitwise_or(args.bitboard.white_bishops)
            |> int.bitwise_or(args.bitboard.white_queens)
            |> int.bitwise_or(args.bitboard.white_king)
            |> int.bitwise_or(args.bitboard.black_pawns)
            |> int.bitwise_or(args.bitboard.black_rooks)
            |> int.bitwise_or(args.bitboard.black_knights)
            |> int.bitwise_or(args.bitboard.black_bishops)
            |> int.bitwise_or(args.bitboard.black_queens)
            |> int.bitwise_or(args.bitboard.black_king)
            |> int.bitwise_and(bit)
          }
          != 0
        })
        Nil
      }),
      #("dict occupancy", fn(args: Arguments) {
        squares
        |> list.map(dict.has_key(args.board, _))
        Nil
      }),
      #("dict get", fn(args: Arguments) {
        squares
        |> list.map(dict.get(args.board, _))
        Nil
      }),
    ]),
    [
      bencher.Warmup(2),
      bencher.Parallel(2),
      bencher.Time(5),
      bencher.Inputs(
        [
          #(
            "starting pos",
            Arguments(
              board: starting |> game.board,
              bitboard: starting
                |> game.board
                |> dict.to_list
                |> bitboard.from_pieces,
            ),
          ),
          #(
            "kiwipete",
            Arguments(
              board: kiwipete |> game.board,
              bitboard: kiwipete
                |> game.board
                |> dict.to_list
                |> bitboard.from_pieces,
            ),
          ),
          #(
            "position3",
            Arguments(
              board: position3 |> game.board,
              bitboard: position3
                |> game.board
                |> dict.to_list
                |> bitboard.from_pieces,
            ),
          ),
          #(
            "midgame_1",
            Arguments(
              board: midgame_1 |> game.board,
              bitboard: midgame_1
                |> game.board
                |> dict.to_list
                |> bitboard.from_pieces,
            ),
          ),
        ]
        |> dict.from_list,
      ),
    ],
  )
}
