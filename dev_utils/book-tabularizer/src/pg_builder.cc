#include "pg_builder.h"
#include "chess.h"
#include "polyglot.h"
#include "tinylogger.h"

/*
 * [reference](http://hgm.nubati.net/book_format.html)
 *
 * "move" is a bit field with the following meaning (bit 0 is the least
 * significant bit)
 *
 * bits                meaning
 * ===================================
 * 0,1,2               to file
 * 3,4,5               to row
 * 6,7,8               from file
 * 9,10,11             from row
 * 12,13,14            promotion piece
 *
 * "promotion piece" is encoded as follows
 *
 * none       0
 * knight     1
 * bishop     2
 * rook       3
 * queen      4
 *
 * If the move is "0" (a1a1) then it should simply be ignored. It seems to me
 * that in that case one might as well delete the entry from the book.
 */
uint16_t encode_move(Move &move) {
  auto from = move.from();
  auto to = move.to();
  uint8_t promotion_piece = 0;

  if (move.typeOf() == Move::CASTLING) {
    if (from == Square::SQ_E1 && to == Square::SQ_G1) {
      // White short
      from = Square::SQ_E1;
      to = Square::SQ_H1;
    } else if (from == Square::SQ_E1 && to == Square::SQ_C1) {
      // White long
      from = Square::SQ_E1;
      to = Square::SQ_A1;
    } else if (from == Square::SQ_E8 && to == Square::SQ_G8) {
      // Black short
      from = Square::SQ_E8;
      to = Square::SQ_H8;
    } else if (from == Square::SQ_E8 && to == Square::SQ_C8) {
      // Black long
      from = Square::SQ_E8;
      to = Square::SQ_H8;
    }
  } else if (move.typeOf() == Move::PROMOTION) {
    switch (move.promotionType()) {
    case PieceType(PieceType::KNIGHT):
      promotion_piece = 1;
      break;
    case PieceType(PieceType::BISHOP):
      promotion_piece = 2;
      break;
    case PieceType(PieceType::ROOK):
      promotion_piece = 3;
      break;
    case PieceType(PieceType::QUEEN):
      promotion_piece = 4;
      break;
    }
  }

  uint16_t to_file = to.file();
  uint16_t to_row = to.rank();
  uint16_t from_file = from.file();
  uint16_t from_row = from.rank();

  uint16_t encoded =
    ( to_file                & 0b0000000000000111) |
    ((to_row          <<  3) & 0b0000000000111000) |
    ((from_file       <<  6) & 0b0000000111000000) |
    ((from_row        <<  9) & 0b0000111000000000) |
    ((promotion_piece << 12) & 0b0111000000000000);

  return encoded;
}

PGBuilder::PGBuilder() {}

PGBuilder::~PGBuilder() {}

void PGBuilder::startPgn() {
  white_elo = -1;
  black_elo = -1;

  white_weight_multiplier = 1;
  black_weight_multiplier = 1;

  plies = 0;
  keep_game = true;

  static int last_num_entries_logged = 0;
  if (entries.size() - last_num_entries_logged > 100000) {
    LOG_DEBUG("read %d entries so far\n", entries.size());
    last_num_entries_logged = entries.size();
  }

  board.setFen(constants::STARTPOS);
}

void PGBuilder::header(std::string_view key, std::string_view value) {
  if (key == "WhiteElo") {
    white_elo = atoi(string(value).c_str());
  } else if (key == "BlackElo") {
    black_elo = atoi(string(value).c_str());
  } else if (key == "Result") {
    // Give more weight to the side that wins
    if (value == "1-0") {
      white_weight_multiplier = 2;
    } else if (value == "0-1") {
      black_weight_multiplier = 2;
    }
  }
}

void PGBuilder::startMoves() {
  keep_game = (
      // Elo wasn't even detected, or
      white_elo == -1 || black_elo == -1 ||
      // Meets elo cutoff, and
      (white_elo > elo_cutoff && black_elo > elo_cutoff &&
       // Elo is within range
       abs(white_elo - black_elo) <= max_elo_diff));
}

void PGBuilder::move(std::string_view san, std::string_view comment) {
  if (!keep_game || plies > max_plies)
    return;

  Move move = uci::parseSan(board, san);
  uint64_t hash = board.hash();
  uint16_t multiplier = board.sideToMove() == Color::WHITE
                            ? white_weight_multiplier
                            : black_weight_multiplier;
  struct BookEntry be = {
      .key = hash, .move = encode_move(move), .weight = multiplier, .learn = 0};
  entries.push_back(be);

  board.makeMove(move);
  plies++;
}

void PGBuilder::endPgn() {}
