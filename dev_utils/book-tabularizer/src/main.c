#include "chess.h"
#include "splitmix64.h"
#include "zobrist.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MAX_MOVES_PER_STATE 256

struct Options {
  uint64_t zobrist_seed;
};

void print_state_group(uint64_t state_group, const uint16_t moves[],
                       uint16_t num_moves) {
  printf("0x%llx -> [", state_group);
  for (int i = 0; i < num_moves; i++) {
    printf("0x%x", moves[i]);
    if (i != num_moves - 1) {
      printf(",");
    }
  }
  printf("]\n");
}

static void parse_args(struct Options *options, int argc, char **argv) {
  int opt;
  while ((opt = getopt(argc, argv, "s:")) != -1) {
    switch (opt) {
    case 's':
      options->zobrist_seed = strtoull(optarg, NULL, 10);
      break;
    case '?':
      fprintf(stderr, "Unknown option %c\n", optopt);
    }
  }
}

/*
 * Read lines in the form of <fen>,<move> from stdin and group each fen with
 * its corresponding moves. Assumes that FENs are already ordered. If they
 * aren't, `sort` them (and may as well pipe into `uniq`)
 *
 * For example, upon reading the lines
 * ```
 * fen1,a2
 * fen1,a3
 * fen1,a4
 * fen2,b1
 * ```
 * We will print:
 * ```
 * fen1 -> [a2, a3, a4]
 * fen2 -> [b1]
 * ```
 */
int main(int argc, char **argv) {
  struct Options options = {.zobrist_seed = 69420};
  struct ZobristTable zobrist_table;
  struct Chess chess;

  // Read options
  parse_args(&options, argc, argv);
  fprintf(stderr, "Running with options:\n");
  fprintf(stderr, "zobrist_seed: %llu\n", options.zobrist_seed);

  // Configure
  seed(options.zobrist_seed);
  zobrist_table_init(&zobrist_table);

  // Start reading
  char *line = NULL;
  size_t size = 0;

  uint64_t state_group = 0;
  uint16_t state_group_num_moves = 0;
  uint16_t moves[MAX_MOVES_PER_STATE];

  char buf[128] = {0};
  uint16_t buf_len = 0;
  uint16_t move = 0;
  uint64_t zobrist_hash;
  char *p;
  while (getline(&line, &size, stdin) != -1) {
    // Each line is <fen>,<from_square>,<to_square>.
    // Go to end of fen and copy it into fen
    for (p = line; *p != '\0' && *p != ','; p++) {
    }
    buf_len = p - line;
    strncpy(buf, line, buf_len);
    buf[buf_len] = '\0';

    chess_from_fen(&chess, buf);
    zobrist_hash = zobrist_table_hash_state(&zobrist_table, &chess);

    // Copy move from and to.
    // From is stored in the upper 8 bits. To is stored in the lower 8 bits.
    move = 0; // Zero it out first
    p++;
    move |= square_from_str(p) << 8;
    p += 3;
    move |= square_from_str(p);

    // Edge case at start: They always form a new state group
    if (state_group == 0) {
      state_group = zobrist_hash;
    }
    // Check if the current state belongs to the group. If it doesn't, print the
    // old group and start a new group.
    // Print the old state group and flush it
    else if (zobrist_hash != state_group) {
      print_state_group(state_group, moves, state_group_num_moves);

      state_group = zobrist_hash;
      state_group_num_moves = 0;
    }

    // In any case, add to the state group -- existing or newly-formed.
    moves[state_group_num_moves++] = move;
  }

  // Don't forget to print the group at the end
  print_state_group(state_group, moves, state_group_num_moves);
}
