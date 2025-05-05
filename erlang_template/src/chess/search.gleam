import chess/evaluate
import chess/game
import gleam/bool
import gleam/dict
import gleam/erlang/process
import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/pair
import gleam/result

pub type SearchMessage {
  SearchUpdate(
    best_move: game.Move,
    game: game.GameHash,
    transposition: TranspositionTable,
  )
}

pub type TranspositionTable {
  TranspositionTable(dict: dict.Dict(game.GameHash, #(Depth, Evaluation)))
}

pub fn transposition_table_new() {
  TranspositionTable(dict.new())
}

pub type Depth =
  Int

pub type Evaluation {
  Evaluation(score: Float, node_type: NodeType, best_move: Option(game.Move))
}

// https://www.chessprogramming.org/Node_Types
pub type NodeType {
  // Exact Score
  PV
  // Lower Bound
  Cut
  // Upper Bound
  All
}

fn evaluation_negate(evaluation: Evaluation) -> Evaluation {
  let node_type = case evaluation.node_type {
    Cut -> All
    All -> Cut
    PV -> PV
  }
  Evaluation(..evaluation, score: float.negate(evaluation.score), node_type:)
}

pub fn new(
  game: game.Game,
  transposition: TranspositionTable,
  search_subject: process.Subject(SearchMessage),
) -> process.Pid {
  // Spawns a searcher thread, NOT linked so we can kill it whenever
  process.start(fn() { search(search_subject, game, 1, transposition) }, False)
}

fn search(
  search_subject: process.Subject(SearchMessage),
  game: game.Game,
  current_depth: Depth,
  transposition: TranspositionTable,
) -> Nil {
  // perform the search at each depth, the negamax function will handle sorting and caching
  let #(best_evaluation, transposition) =
    negamax_alphabeta_failsoft(game, current_depth, -1.0, 1.0, transposition)
  let Evaluation(_score, _node_type, best_move) = best_evaluation

  case best_move {
    Some(best_move) ->
      process.send(
        search_subject,
        SearchUpdate(best_move, game.to_hash(game), transposition),
      )
    None -> Nil
  }
  search(search_subject, game, current_depth + 1, transposition)
}

// https://www.chessprogramming.org/Alpha-Beta#Negamax_Framework
// returns the score of the current game searched at depth
// uses negamax version of alpha beta pruning with failsoft
// scores are from the perspective of the active player
// If white's turn, +1 is white's advantage
// If black's turn, +1 is black's advantage
// alpha is the "best" score for active player
// beta is the "best" score for non-active player

fn negamax_alphabeta_failsoft(
  game: game.Game,
  depth: Depth,
  alpha: Float,
  beta: Float,
  transposition: TranspositionTable,
) -> #(Evaluation, TranspositionTable) {
  let game_hash = game.to_hash(game)

  // TODO: check for cache collision here
  let cached_evaluation =
    dict.get(transposition.dict, game_hash)
    |> result.then(fn(x) {
      let #(cached_depth, evaluation) = x
      use <- bool.guard(cached_depth < depth, Error(Nil))
      case evaluation {
        Evaluation(_, PV, _) -> Ok(evaluation)
        Evaluation(score, Cut, _) if score >=. beta -> Ok(evaluation)
        Evaluation(score, All, _) if score <=. alpha -> Ok(evaluation)
        _ -> Error(Nil)
      }
    })

  use <- result.lazy_unwrap(
    result.map(cached_evaluation, pair.new(_, transposition)),
  )

  let #(evaluation, transposition) =
    do_negamax_alphabeta_failsoft(game, depth, alpha, beta, transposition)

  let transposition =
    TranspositionTable(
      dict: dict.insert(transposition.dict, game_hash, #(depth, evaluation)),
    )

  #(evaluation, transposition)
}

fn do_negamax_alphabeta_failsoft(
  game: game.Game,
  depth: Depth,
  alpha: Float,
  beta: Float,
  transposition: TranspositionTable,
) -> #(Evaluation, TranspositionTable) {
  use <- bool.lazy_guard(depth <= 0, fn() {
    let score = quiesce(game, alpha, beta)
    #(Evaluation(score:, node_type: PV, best_move: None), transposition)
  })

  let move_game_list = sorted_moves(game, transposition)

  use <- bool.lazy_guard(list.is_empty(move_game_list), fn() {
    // if checkmate/stalemate
    let score = case game.is_check(game) {
      True -> -1.0
      False -> 0.0
    }
    #(Evaluation(score:, node_type: PV, best_move: None), transposition)
  })

  // We iterate through every move and perform minimax to evaluate said move
  // accumulator keeps track of best evaluation while updating the node type
  let #(best_evaluation, _alpha, transposition) =
    list.fold_until(
      move_game_list,
      #(Evaluation(-1.0, PV, None), alpha, transposition),
      fn(acc, move_game) {
        let #(best_evaluation, alpha, transposition) = acc
        let #(move, game) = move_game
        let #(evaluation, transposition) =
          negamax_alphabeta_failsoft(
            game,
            depth - 1,
            float.negate(beta),
            float.negate(alpha),
            transposition,
          )
        let evaluation =
          Evaluation(..evaluation_negate(evaluation), best_move: Some(move))
        let best_evaluation = case best_evaluation.score <. evaluation.score {
          True -> evaluation
          False -> best_evaluation
        }
        let alpha = float.max(alpha, evaluation.score)

        // beta-cutoff
        case evaluation.score >=. beta {
          True -> {
            let best_evaluation = Evaluation(..best_evaluation, node_type: Cut)
            list.Stop(#(best_evaluation, alpha, transposition))
          }
          False -> list.Continue(#(best_evaluation, alpha, transposition))
        }
      },
    )

  #(best_evaluation, transposition)
}

// returns the score of the current game while checking
// every capture and check
// scores are from the perspective of the active player
// If white's turn, +1 is white's advantage
// If black's turn, +1 is black's advantage
// alpha is the "best" score for active player
// beta is the "best" score for non-active player
fn quiesce(game: game.Game, alpha: Float, beta: Float) -> Float {
  let score = evaluate.game(game) *. evaluate.player(game.turn(game))
  use <- bool.guard(score >=. beta, score)
  let alpha = float.max(alpha, score)

  let move_game_list =
    game.moves(game)
    |> list.map(fn(move) {
      let assert Ok(new_game) = game.apply(game, move)
      #(move, new_game)
    })
  let #(best_score, _) =
    move_game_list
    |> list.filter(fn(move_game) {
      let #(move, _new_game) = move_game
      game.move_is_capture(move)
    })
    |> list.fold_until(#(score, alpha), fn(acc, move_game) {
      let #(_move, new_game) = move_game
      let #(best_score, alpha) = acc
      let score =
        float.negate(quiesce(new_game, float.negate(beta), float.negate(alpha)))

      use <- bool.guard(score >=. beta, list.Stop(#(score, alpha)))
      list.Continue(#(float.max(best_score, score), float.max(alpha, score)))
    })
  best_score
}

// sort moves from best to worse, which improves alphabeta pruning
fn sorted_moves(
  game: game.Game,
  transposition: TranspositionTable,
) -> List(#(game.Move, game.Game)) {
  game.moves(game)
  |> list.map(fn(move) {
    // retrieve the cached transposition table data
    // negate the evaluation so that it's relative to our current game
    let assert Ok(new_game) = game.apply(game, move)
    let evaluation = case dict.get(transposition.dict, game.to_hash(new_game)) {
      Ok(#(_, evaluation)) -> Some(evaluation_negate(evaluation))
      Error(Nil) -> None
    }
    #(#(move, new_game), evaluation)
  })
  // "smallest" elements get sorted first
  |> list.sort(fn(a, b) {
    let #(_a_move, a) = a
    let #(_b_move, b) = b
    case a, b {
      None, None -> order.Eq
      _, None -> order.Lt
      None, _ -> order.Gt
      Some(a), Some(b) -> {
        case a, b {
          Evaluation(_, Cut, _), _ -> order.Gt
          _, Evaluation(_, Cut, _) -> order.Lt
          Evaluation(a_score, _, _), Evaluation(b_score, _, _) ->
            float.compare(b_score, a_score)
        }
      }
    }
  })
  |> list.map(pair.first)
}
