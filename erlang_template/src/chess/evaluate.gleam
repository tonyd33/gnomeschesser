import chess/game
import chess/piece
import chess/player
import gleam/bool
import gleam/dict
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam_community/maths

pub type Evaluation {
  Evaluation(score: Float, move: Option(game.Move))
}

pub opaque type MemoizationObject {
  MemoizationObject(dict: dict.Dict(Int, #(Int, Evaluation)))
}

pub fn new_memoization_object() {
  MemoizationObject(dict.new())
}

fn memoization_insert(
  memo: MemoizationObject,
  index: Int,
  value: #(Int, Evaluation),
  // #(depth, evaluation)
) {
  MemoizationObject(dict.insert(memo.dict, index, value))
}

pub fn search(
  game: game.Game,
  depth: Int,
  memo: MemoizationObject,
) -> #(Evaluation, MemoizationObject) {
  negamax_alphabeta_failsoft(game, depth, -1.0, 1.0, memo)
}

// https://www.chessprogramming.org/Alpha-Beta#Negamax_Framework
fn negamax_alphabeta_failsoft(
  game: game.Game,
  depth: Int,
  alpha: Float,
  beta: Float,
  memo: MemoizationObject,
) -> #(Evaluation, MemoizationObject) {
  let depth = int.max(0, depth)
  // TODO: clean up memoization
  use <- bool.lazy_guard(depth < 0, fn() {
    panic as "This isn't supposed to happen"
  })
  let memo_index = game.to_hash(game)
  let memo_result =
    dict.get(memo.dict, memo_index)
    |> result.try(fn(memo_result) {
      case memo_result.0 >= depth {
        True -> Ok(#(memo_result.1, memo))
        False -> Error(Nil)
      }
    })
  use <- result.lazy_unwrap(memo_result)
  case depth <= 0 {
    True -> {
      let evaluation = Evaluation(quiesce(game, alpha, beta), None)
      let memo = memoization_insert(memo, memo_index, #(depth, evaluation))
      #(evaluation, memo)
    }
    False -> {
      let moves = game.moves(game)
      use <- bool.lazy_guard(list.is_empty(moves), fn() {
        let evaluation =
          case game.is_check(game) {
            True -> 1.0
            False -> 0.0
          }
          |> Evaluation(None)
        let memo = memoization_insert(memo, memo_index, #(depth, evaluation))
        #(evaluation, memo)
      })

      let #(evaluation, memo, _) =
        list.fold_until(
          moves,
          #(Evaluation(-1.0, None), memo, alpha),
          fn(acc, move) {
            let #(Evaluation(best_value, _), memo, alpha) = acc
            let assert Ok(game) = game.apply(game, move)
            let #(Evaluation(score, _), memo) =
              negamax_alphabeta_failsoft(
                game,
                depth - 1,
                float.negate(beta),
                float.negate(alpha),
                memo,
              )
            let score = float.negate(score)
            let acc = case best_value <. score {
              True -> #(
                Evaluation(score, Some(move)),
                memo,
                float.max(alpha, score),
              )
              False -> acc
            }
            case score >=. beta {
              True -> list.Stop(acc)
              False -> list.Continue(acc)
            }
          },
        )

      let memo = memoization_insert(memo, memo_index, #(depth, evaluation))
      #(evaluation, memo)
    }
  }
}

fn quiesce(game: game.Game, alpha: Float, beta: Float) -> Float {
  let score = evaluate_game(game) *. evaluate_player(game.turn(game))
  use <- bool.guard(score >=. beta, score)
  let alpha = float.max(alpha, score)
  let moves = game.moves(game)
  let #(best_score, _) =
    list.fold_until(moves, #(score, alpha), fn(acc, move) {
      let #(best_score, alpha) = acc
      let assert Ok(game) = game.apply(game, move)
      let score =
        float.negate(quiesce(game, float.negate(beta), float.negate(alpha)))
      use <- bool.guard(score >=. beta, list.Stop(#(score, alpha)))
      list.Continue(#(float.max(best_score, score), float.max(alpha, score)))
    })
  best_score
}

fn evaluate_game(game: game.Game) -> Float {
  let score =
    game.pieces(game)
    |> list.fold(0.0, fn(score, square_piece) {
      score +. evaluate_piece(square_piece.1)
    })
  let normalized_score = maths.atan(score /. 4.0) /. maths.pi() /. 2.0
  normalized_score
}

fn evaluate_piece(piece: piece.Piece) -> Float {
  case piece.symbol {
    piece.Pawn -> 1.0
    piece.Knight -> 3.0
    piece.Bishop -> 3.0
    piece.Rook -> 5.0
    piece.Queen -> 9.0
    piece.King -> 0.0
  }
  *. evaluate_player(piece.player)
}

fn evaluate_player(player: player.Player) -> Float {
  case player {
    player.White -> 1.0
    player.Black -> -1.0
  }
}
