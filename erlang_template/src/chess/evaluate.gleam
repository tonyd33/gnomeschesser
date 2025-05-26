import chess/evaluate/common
import chess/evaluate/midgame
import chess/evaluate/psqt
import chess/game
import chess/piece
import chess/player
import gleam/int
import gleam/list
import util/xint.{type ExtendedInt}

pub type Score =
  ExtendedInt

/// Evaluates the score of the game position
/// > 0 means white is winning
/// < 0 means black is winning
///
pub fn game(game: game.Game) -> Score {
  let pieces = game.pieces(game)
  // TODO: use a cached version of getting moves somehow?
  let our_moves = game.valid_moves(game)

  let scores = material_scores(pieces)
  let phase = phase(scores.npm)

  let material_score = flatten_sided_score(scores.material)

  let PSQScores(mg, eg) = psq_scores(pieces)
  let psq_score =
    {
      { flatten_sided_score(mg) * phase }
      + { flatten_sided_score(eg) * { 100 - phase } }
    }
    / 100

  // TODO: change these based on the state of the game
  let mobility_score = midgame.mobility(our_moves)
  let king_safety_score =
    midgame.king_pawn_shield(game, player.White)
    + midgame.king_pawn_shield(game, player.Black)
  // combine scores with weight
  {
    {
      { material_score * 850 }
      + { psq_score * 850 }
      + { mobility_score * 10 }
      + { king_safety_score * 40 }
    }
    / { 850 + 850 + 10 + 40 }
  }
  |> xint.from_int
}

/// Returns a value 0-100 such that:
/// - A value of 0 means we're completely in the endgame
/// - A value of 100 means we're completely in the midgame (or before it)
/// - A value in between signifies the weight endgame should be given, scaling
///   linearly.
/// This is closely tied to the values in common.gleam!!
///
pub fn phase(npm_score: SidedScore) -> Int {
  // We'll calculate a measure, clamp them between two bounds, and then treat
  // it as the interpolated value between midgame and endgame after scaling.
  //
  // Endgame limit                                              Midgame limit
  //       v                                                          v
  //       |=========== * ============================================|
  //       ^            ^                                             ^
  //       0         measure                                         100
  //
  // We'll use a simple measure: non-pawn material value (npm). Pawns often get
  // traded back and forth in the midgame, and it's usually only approaching
  // the endgame that non-pawns start to be taken.
  //
  // This follows a similar strategy as Stockfish and gives a pretty similar
  // result. (note they scale from 0-128).
  // See: https://hxim.github.io/Stockfish-Evaluation-Guide/

  let SidedScore(npm_white, npm_black) = npm_score

  let midgame_limit = 15_258
  let endgame_limit = 3915

  let npm =
    { npm_white + npm_black }
    |> int.max(endgame_limit)
    |> int.min(midgame_limit)
  { { npm - endgame_limit } * 100 } / { midgame_limit - endgame_limit }
}

pub const piece_symbol = common.piece_symbol

pub const player = common.player

pub type SidedScore {
  SidedScore(white: Int, black: Int)
}

pub const empty_sided_score = SidedScore(0, 0)

pub fn add_sided_score(s1: SidedScore, s2: SidedScore) {
  SidedScore(white: s1.white + s2.white, black: s1.black + s2.black)
}

pub fn flatten_sided_score(s: SidedScore) -> Int {
  { s.white * common.player(player.White) }
  + { s.black * common.player(player.Black) }
}

fn process_material_score(_square, piece: piece.Piece) {
  case piece.player {
    player.White ->
      SidedScore(white: common.piece_symbol(piece.symbol), black: 0)
    player.Black ->
      SidedScore(white: 0, black: common.piece_symbol(piece.symbol))
  }
}

fn process_npm_score(_square, piece: piece.Piece) {
  case piece {
    piece.Piece(_, piece.Pawn) -> SidedScore(white: 0, black: 0)
    piece.Piece(player.White, symbol) ->
      SidedScore(
        white: common.piece_value_bonus(symbol, common.MidGame),
        black: 0,
      )
    piece.Piece(player.Black, symbol) ->
      SidedScore(
        white: 0,
        black: common.piece_value_bonus(symbol, common.MidGame),
      )
  }
}

pub type MaterialScores {
  MaterialScores(material: SidedScore, npm: SidedScore)
}

const empty_material_scores = MaterialScores(
  empty_sided_score,
  empty_sided_score,
)

fn add_material_scores(s1: MaterialScores, s2: MaterialScores) {
  MaterialScores(
    add_sided_score(s1.material, s2.material),
    add_sided_score(s1.npm, s2.npm),
  )
}

fn process_material_scores(square, piece: piece.Piece) {
  MaterialScores(
    material: process_material_score(square, piece),
    npm: process_npm_score(square, piece),
  )
}

pub fn material_scores(pieces) {
  use acc, #(square, piece) <- list.fold(pieces, empty_material_scores)
  process_material_scores(square, piece) |> add_material_scores(acc)
}

pub type PSQScores {
  PSQScores(midgame: SidedScore, endgame: SidedScore)
}

const empty_psq_scores = PSQScores(empty_sided_score, empty_sided_score)

fn add_psq_scores(s1: PSQScores, s2: PSQScores) {
  PSQScores(
    add_sided_score(s1.midgame, s2.midgame),
    add_sided_score(s1.endgame, s2.endgame),
  )
}

fn process_psq_mg_score(square, piece: piece.Piece) {
  case piece.player {
    player.White ->
      SidedScore(
        white: psqt.get_psq_score(piece, square, common.MidGame),
        black: 0,
      )
    player.Black ->
      SidedScore(
        white: 0,
        black: -psqt.get_psq_score(piece, square, common.MidGame),
      )
  }
}

fn process_psq_eg_score(square, piece: piece.Piece) {
  case piece.player {
    player.White ->
      SidedScore(
        white: psqt.get_psq_score(piece, square, common.EndGame),
        black: 0,
      )
    player.Black ->
      SidedScore(
        white: 0,
        black: -psqt.get_psq_score(piece, square, common.EndGame),
      )
  }
}

fn process_psq_scores(square, piece: piece.Piece) {
  PSQScores(
    process_psq_mg_score(square, piece),
    process_psq_eg_score(square, piece),
  )
}

pub fn psq_scores(pieces) {
  use acc, #(square, piece) <- list.fold(pieces, empty_psq_scores)
  process_psq_scores(square, piece) |> add_psq_scores(acc)
}
