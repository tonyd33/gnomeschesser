import chess/evaluate
import chess/game
import gleam/bool
import gleam/dict
import gleam/erlang/process
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/pair
import gleam/result
import util/yielder

pub type Evaluation {
  Evaluation(score: Float, move: Option(game.Move))
}

pub opaque type TranspositionTable {
  TranspositionTable(dict: dict.Dict(game.GameHash, #(Depth, Float)))
}

pub fn memoization_new() {
  TranspositionTable(dict.new())
}

type Depth =
  Int

fn memoization_insert(
  transposition: TranspositionTable,
  index: game.GameHash,
  value: #(Depth, Float),
) {
  TranspositionTable(dict.insert(transposition.dict, index, value))
}

pub type SearchMessage {
  SearchUpdate(best_move: game.Move, transposition: TranspositionTable)
}

pub fn new(
  game: game.Game,
  transposition: TranspositionTable,
  search_subject: process.Subject(SearchMessage),
) -> process.Pid {
  // Spawns a searcher thread, NOT linked so we can kill it whenever
  process.start(fn() { search(game, transposition, search_subject) }, False)
}

fn search(
  game: game.Game,
  transposition: TranspositionTable,
  search_subject: process.Subject(SearchMessage),
) -> Nil {
  // Pre-compute all of the associated games after the move is made
  let move_game_list =
    game.moves(game)
    |> list.map(fn(move) {
      let assert Ok(new_game) = game.apply(game, move)
      #(move, new_game)
    })

  use <- bool.guard(list.is_empty(move_game_list), Nil)

  // shuffle the list to not have deterministic results
  // can remove if the evaluation becomes more interesting
  let move_game_list = list.shuffle(move_game_list)

  // Use a yielder to iterate through depths indefinitely
  yielder.iterate(0, int.add(_, 1))
  |> yielder.fold(transposition, fn(transposition, depth) {
    echo depth
    // TODO: implement transposition tables and sort moves based on the scores from there
    //let move_game_list = sort_moves(move_game_list, transposition)

    // We iterate through every move and perform minimax to evaluate said move
    // accumulator keeps track of best score and best move
    let assert #(_best_score, Some(best_move), transposition) =
      list.fold(
        move_game_list,
        #(-1.0, None, transposition),
        fn(acc, move_game) {
          let #(best_score, best_move, transposition) = acc
          let #(move, new_game) = move_game
          let #(new_score, transposition) =
            negamax_alphabeta_failsoft(
              new_game,
              depth,
              -1.0,
              float.negate(best_score),
              transposition,
            )
          let new_score = float.negate(new_score)

          let #(best_score, best_move) = case best_score >=. new_score {
            True -> #(best_score, best_move)
            False -> #(new_score, Some(move))
          }

          #(best_score, best_move, transposition)
        },
      )
    process.send(search_subject, SearchUpdate(best_move, transposition))

    transposition
  })
  Nil
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
) -> #(Float, TranspositionTable) {
  use <- bool.lazy_guard(depth <= 0, fn() {
    let score = quiesce(game, alpha, beta)
    #(score, transposition)
  })

  let moves = game.moves(game)

  use <- bool.lazy_guard(list.is_empty(moves), fn() {
    // if checkmate/stalemate
    let score = case game.is_check(game) {
      True -> -1.0
      False -> 0.0
    }
    #(score, transposition)
  })

  // recalculate the new game state of each move applied
  let move_game_list =
    game.moves(game)
    |> list.map(fn(move) {
      let assert Ok(new_game) = game.apply(game, move)
      #(move, new_game)
    })

  // TODO: implement transposition tables and sort moves based on the scores from there
  // sort moves from previously calculated scores for better pruning
  //let move_game_list = sort_moves(move_game_list, transposition)

  // We iterate through every move and perform minimax to evaluate said move
  // accumulator keeps track of best score and best move
  let #(best_score, _alpha, transposition) =
    list.fold_until(
      move_game_list,
      #(-1.0, alpha, transposition),
      fn(acc, move_game) {
        let #(best_value, alpha, transposition) = acc
        let #(_move, game) = move_game
        let #(score, transposition) =
          negamax_alphabeta_failsoft(
            game,
            depth - 1,
            float.negate(beta),
            float.negate(alpha),
            transposition,
          )
        let score = float.negate(score)
        let acc = case best_value <. score {
          True -> #(
            float.max(best_value, score),
            float.max(alpha, score),
            transposition,
          )
          False -> acc
        }
        case score >=. beta {
          True -> list.Stop(acc)
          False -> list.Continue(acc)
        }
      },
    )

  #(best_score, transposition)
}

// returns the score of the current game while checking
// every capture 
// scores are from the perspective of the active player
// If white's turn, +1 is white's advantage
// If black's turn, +1 is black's advantage
// alpha is the "best" score for active player
// beta is the "best" score for non-active player
fn quiesce(game: game.Game, alpha: Float, beta: Float) -> Float {
  let score = evaluate.game(game) *. evaluate.player(game.turn(game))
  use <- bool.guard(score >=. beta, score)
  let alpha = float.max(alpha, score)
  let moves = game.moves(game)
  let #(best_score, _) =
    moves
    |> list.filter(game.move_is_capture)
    |> list.fold_until(#(score, alpha), fn(acc, move) {
      let #(best_score, alpha) = acc
      let assert Ok(game) = game.apply(game, move)
      let score =
        float.negate(quiesce(game, float.negate(beta), float.negate(alpha)))

      use <- bool.guard(score >=. beta, list.Stop(#(score, alpha)))
      list.Continue(#(float.max(best_score, score), float.max(alpha, score)))
    })
  best_score
}

// sort moves from best to worse, which improves alphabeta pruning
fn sort_moves(
  move_games: List(#(game.Move, game.Game)),
  transposition: TranspositionTable,
) -> List(#(game.Move, game.Game)) {
  move_games
  |> list.map(fn(move_game) {
    let #(_move, new_game) = move_game
    let score = case dict.get(transposition.dict, game.to_hash(new_game)) {
      Error(Nil) -> None
      Ok(#(_, score)) -> Some(score)
    }
    #(move_game, score)
  })
  |> list.sort(fn(a, b) {
    case a.1, b.1 {
      Some(a), Some(b) -> float.compare(b, a)
      None, None -> order.Eq
      _, None -> order.Lt
      None, _ -> order.Gt
    }
  })
  |> list.map(pair.first)
}
