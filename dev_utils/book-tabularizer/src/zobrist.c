#include "zobrist.h"
#include "splitmix64.h"

void zobrist_table_init(struct ZobristTable *zobrist_table) {
  int i;
  for (i = 0; i < 768; i++) {
    zobrist_table->board[i] = next();
  }
  zobrist_table->black = next();
  for (i = 0; i < 16; i++) {
    zobrist_table->castling_rights[i] = next();
  }
  for (i = 0; i < 8; i++) {
    zobrist_table->en_passant_file[i] = next();
  }
}

uint64_t zobrist_table_hash_state(const struct ZobristTable *zobrist_table,
                                  const struct Chess *state) {
  uint64_t h = 0;
  int i, slice_n;
  for (i = 0; i < 64; i++) {
    if (state->board[i] == NO_PIECE)
      continue;
    slice_n = state->board[i];
    h ^= zobrist_table->board[slice_n * 64 + i];
  }
  if (state->color == BLACK)
    h ^= zobrist_table->black;
  h ^= zobrist_table->castling_rights[state->castling_rights];
  if (state->ep_square != SQUARE_ZERO)
    h ^= zobrist_table->en_passant_file[file_of(state->ep_square)];
  return h;
}
