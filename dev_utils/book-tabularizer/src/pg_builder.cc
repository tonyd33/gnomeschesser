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
  uint8_t to_file = move.to().file();
  uint8_t to_row = move.to().rank();
  uint8_t from_file = move.from().file();
  uint8_t from_row = move.from().rank();

  uint8_t promotion_piece;
  if (move.typeOf() == Move::PROMOTION) {
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
  } else {
    promotion_piece = 0;
  }

  uint16_t encoded = ((promotion_piece & ((1U << 3) - 1)) << 12) |
                     ((from_row & ((1U << 3) - 1)) << 9) |
                     ((from_file & ((1U << 3) - 1)) << 6) |
                     ((to_row & ((1U << 3) - 1)) << 3) |
                     ((to_file & ((1U << 3) - 1)));

  return encoded;
}

PGBuilder::PGBuilder() {}

PGBuilder::~PGBuilder() {}

void PGBuilder::startPgn() {
  keep_game = true;
  white_elo = -1;
  black_elo = -1;
  plies = 0;

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
  struct BookEntry be = {
      .key = hash, .move = encode_move(move), .weight = 1, .learn = 0};
  entries.push_back(be);

  board.makeMove(move);
  plies++;
}

void PGBuilder::endPgn() {}
