#ifndef _ZOBRIST_H_
#define _ZOBRIST_H_
#include "stdint.h"
#include "chess.h"

struct ZobristTable {
  uint64_t board[768];
  uint64_t black;
  uint64_t castling_rights[16];
  uint64_t en_passant_file[8];
};

void zobrist_table_init(struct ZobristTable *);

uint64_t zobrist_table_hash_state(const struct ZobristTable *zobrist_table,
                                  const struct Chess *state);

#endif /* _ZOBRIST_H_ */
