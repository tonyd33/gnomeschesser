import chess/bitboard
import chess/game
import chess/player
import chess/square
import gleam/int
import gleam/list
import gleam/result
import gleam/string

fn squares_to_bitmask(squares) {
  list.fold(squares, 0, fn(acc, square) {
    int.bitwise_or(acc, bitboard.from_square(square))
  })
}

fn construct_bitmask_for_count(squares) {
  let proper = squares_to_bitmask(squares)

  let combs =
    list.range(0, list.length(squares))
    |> list.flat_map(fn(i) {
      list.combinations(squares, i)
      |> list.map(fn(comb) { #(squares_to_bitmask(comb), i) })
    })

  "case int.bitwise_and(bb, 0b"
  <> int.to_base2(proper)
  <> ") {\n"
  <> list.map(combs, fn(x) {
    let #(bits, count) = x
    "0b" <> int.to_base2(bits) <> "->" <> int.to_string(count)
  })
  |> string.join("\n")
  <> "\n"
  <> "_ -> 0\n"
  <> "}"
}

fn pawns_close_gen() {
  let for_side = fn(king_square, side) {
    let king_rank = square.rank(king_square)
    let king_file = square.file(king_square)
    let rank_offset = case side {
      player.Black -> -1
      player.White -> 1
    }
    let pawns_close =
      [
        square.from_rank_file(king_rank + rank_offset, king_file - 1),
        square.from_rank_file(king_rank + rank_offset, king_file),
        square.from_rank_file(king_rank + rank_offset, king_file + 1),
      ]
      |> result.values
    int.to_string(king_square)
    <> "->"
    <> construct_bitmask_for_count(pawns_close)
  }
  "case player {\n"
  <> "player.White ->\n"
  <> "case king_square {\n"
  <> list.map([4], for_side(_, player.White))
  |> string.join("\n")
  <> "\n"
  <> "_ -> panic\n"
  <> "}"
  <> "\n"
  <> "player.Black ->\n"
  <> "case king_square {\n"
  <> list.map([4], for_side(_, player.Black))
  |> string.join("\n")
  <> "\n"
  <> "_ -> panic\n"
  <> "}"
  <> "\n"
  <> "}"
}

fn pawns_far_gen() {
  let for_side = fn(king_square, side) {
    let king_rank = square.rank(king_square)
    let king_file = square.file(king_square)
    let rank_offset = case side {
      player.Black -> -1
      player.White -> 1
    }
    let pawns_far =
      [
        square.from_rank_file(king_rank + rank_offset * 2, king_file - 1),
        square.from_rank_file(king_rank + rank_offset * 2, king_file),
        square.from_rank_file(king_rank + rank_offset * 2, king_file + 1),
      ]
      |> result.values
    int.to_string(king_square) <> "->" <> construct_bitmask_for_count(pawns_far)
  }
  "case player {\n"
  <> "player.White ->\n"
  <> "case king_square {\n"
  <> list.map(square.get_squares(), for_side(_, player.White))
  |> string.join("\n")
  <> "\n"
  <> "_ -> panic\n"
  <> "}"
  <> "\n"
  <> "player.Black ->\n"
  <> "case king_square {\n"
  <> list.map(square.get_squares(), for_side(_, player.Black))
  |> string.join("\n")
  <> "\n"
  <> "_ -> panic\n"
  <> "}"
  <> "\n"
  <> "}"
}

pub fn main() {
  // io.println(pawns_far_gen())
  let assert Ok(game) = game.load_fen("4k3/5p2/3pp3/8/8/3P4/4PP2/4K3 w - - 0 1")
  let bb = bitboard.from_pieces(game.pieces(game))
  echo int.to_base2(bb.white_pawns)
  // let white_king = echo game.find_player_king(game, player.White)
  // echo int.to_base2(int.bitwise_or(bb.white_pawns, 0b00000011100000000000))
  // echo midgame.count_pawns_close(white_king, player.White, bb.white_pawns)
}
