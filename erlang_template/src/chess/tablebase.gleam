import chess/game.{type Game}
import chess/move.{type Move, type ValidInContext}
import chess/tablebase/data
import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/result

pub type Tablebase =
  Dict(Int, List(#(Int, Int)))

pub fn load() -> Tablebase {
  dict.from_list(data.table)
}

/// Picks a random element from a weighted list. Runs in linear time and
/// iterates through the list twice.
///
pub fn pick_weighted_random(xs: List(#(a, Int))) -> Result(a, Nil) {
  // The algorithm is dead simple and could be improved but is good enough
  // for us:
  // The weights define an interval:
  // [#(a1, w1), #(a2, w2), ..., #(an, wn)]
  //
  // 0   w1     w1+w2          w1+..+wn
  // | a1 |  a2   |    ...   | an |
  // Roll a number uniformly between 0 to (w1+...+wn). This corresponds to one
  // of the intervals, and thus one of the an's. Pick that one.
  //

  let #(total, cdf) =
    list.map_fold(xs, 0, fn(acc, x) { #(acc + x.1, #(x.0, acc + x.1)) })
  let roll = float.round(float.random() *. int.to_float(total))

  use #(x, n) <- list.find_map(cdf)
  case roll <= n {
    True -> Ok(x)
    False -> Error(Nil)
  }
}

/// Query to see if there are any moves for this game in our tablebase.
///
pub fn query(tb: Tablebase, game: Game) -> Result(Move(ValidInContext), Nil) {
  // TODO: Consider also looking up for a mirrored version of the game
  // and returning a mirrored move. Not particularly useful for openings,
  // but may be useful for endings.
  use enc_moves <- result.try(dict.get(tb, game.hash(game)))
  let weighted_moves = {
    use #(enc_move, weight) <- list.filter_map(enc_moves)
    use move <- result.try(move.decode_pg(enc_move))
    use validated_move <- result.try(game.validate_move(move, game))
    Ok(#(validated_move, weight))
  }
  pick_weighted_random(weighted_moves)
}

pub fn empty() -> Tablebase {
  dict.new()
}
