#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define MAX_FEN_LEN 128
#define MAX_MOVES_PER_FEN 256
#define MAX_SAN_LEN 8
#define MIN(a, b) (((a) < (b)) ? (a) : (b))

void print_fen_group(const char *fen_group, const char moves[][MAX_SAN_LEN],
                     uint16_t num_moves) {
  printf("\"%s\" -> [", fen_group);
  for (int i = 0; i < num_moves; i++) {
    printf("\"%s\"", moves[i]);
    if (i != num_moves - 1) {
      printf(",");
    }
  }
  printf("]\n");
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
  char *line = NULL;
  size_t size = 0;

  char fen_group[MAX_FEN_LEN] = {0};
  uint16_t fen_group_num_moves = 0;
  char moves[MAX_MOVES_PER_FEN][MAX_SAN_LEN];

  char fen[MAX_FEN_LEN] = {0};
  char move[MAX_SAN_LEN] = {0};
  uint16_t fen_len = 0;
  uint16_t move_len = 0;
  char *p;
  while (getline(&line, &size, stdin) != -1) {
    // Each line is <fen>,<move>.
    // Go to end of fen and copy it into fen
    for (p = line; *p != '\0' && *p != ',' && p - line < MIN(MAX_FEN_LEN, size);
         p++) {
    }
    fen_len = p - line;
    strncpy(fen, line, fen_len);
    fen[fen_len] = '\0';

    // Go to end of line and copy it into move
    for (p++; *p != '\0' && *p != '\n' && p - line < MIN(MAX_FEN_LEN, size);
         p++) {
    }
    move_len = p - line - fen_len - 1;
    strncpy(move, p - move_len, move_len);
    move[move_len] = '\0';

    // Edge case at start: They always form a new fen group
    if (fen_group[0] == '\0') {
      strncpy(fen_group, fen, fen_len);
      fen_group[fen_len] = '\0';
    }
    // Check if the current fen belongs to the group. If it doesn't, print the
    // old group and start a new group.
    // Print the old fen group and flush it
    else if (strncmp(fen, fen_group, fen_len) != 0) {
      print_fen_group(fen_group, moves, fen_group_num_moves);

      strncpy(fen_group, fen, fen_len);
      fen_group[fen_len] = '\0';
      fen_group_num_moves = 0;
    }

    // In any case, add to the fen group -- existing or newly-formed.
    strncpy(moves[fen_group_num_moves], move, move_len);
    moves[fen_group_num_moves][move_len] = '\0';
    fen_group_num_moves++;
  }

  // Don't forget to print the group at the end
  print_fen_group(fen_group, moves, fen_group_num_moves);
}
