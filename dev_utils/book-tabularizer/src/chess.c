#include "chess.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

enum Piece piece_from_char(char c) {
  switch (c) {
  case 'P':
    return W_PAWN;
  case 'N':
    return W_KNIGHT;
  case 'B':
    return W_BISHOP;
  case 'R':
    return W_ROOK;
  case 'Q':
    return W_QUEEN;
    break;
  case 'K':
    return W_KING;
    break;
  case 'p':
    return B_PAWN;
  case 'n':
    return B_KNIGHT;
  case 'b':
    return B_BISHOP;
  case 'r':
    return B_ROOK;
  case 'q':
    return B_QUEEN;
  case 'k':
    return B_KING;
    break;
  default:
    return NO_PIECE;
  }
}

enum Square square_from_str(char *s) {
  switch (s[0]) {
  case 'a':
    switch (s[1]) {
    case '1':
      return SQ_A1;
    case '2':
      return SQ_A2;
    case '3':
      return SQ_A3;
    case '4':
      return SQ_A4;
    case '5':
      return SQ_A5;
    case '6':
      return SQ_A6;
    case '7':
      return SQ_A7;
    case '8':
      return SQ_A8;
    }
  case 'b':
    switch (s[1]) {
    case '1':
      return SQ_B1;
    case '2':
      return SQ_B2;
    case '3':
      return SQ_B3;
    case '4':
      return SQ_B4;
    case '5':
      return SQ_B5;
    case '6':
      return SQ_B6;
    case '7':
      return SQ_B7;
    case '8':
      return SQ_B8;
    }
  case 'c':
    switch (s[1]) {
    case '1':
      return SQ_C1;
    case '2':
      return SQ_C2;
    case '3':
      return SQ_C3;
    case '4':
      return SQ_C4;
    case '5':
      return SQ_C5;
    case '6':
      return SQ_C6;
    case '7':
      return SQ_C7;
    case '8':
      return SQ_C8;
    }
  case 'd':
    switch (s[1]) {
    case '1':
      return SQ_D1;
    case '2':
      return SQ_D2;
    case '3':
      return SQ_D3;
    case '4':
      return SQ_D4;
    case '5':
      return SQ_D5;
    case '6':
      return SQ_D6;
    case '7':
      return SQ_D7;
    case '8':
      return SQ_D8;
    }
  case 'e':
    switch (s[1]) {
    case '1':
      return SQ_E1;
    case '2':
      return SQ_E2;
    case '3':
      return SQ_E3;
    case '4':
      return SQ_E4;
    case '5':
      return SQ_E5;
    case '6':
      return SQ_E6;
    case '7':
      return SQ_E7;
    case '8':
      return SQ_E8;
    }
  case 'f':
    switch (s[1]) {
    case '1':
      return SQ_F1;
    case '2':
      return SQ_F2;
    case '3':
      return SQ_F3;
    case '4':
      return SQ_F4;
    case '5':
      return SQ_F5;
    case '6':
      return SQ_F6;
    case '7':
      return SQ_F7;
    case '8':
      return SQ_F8;
    }
  case 'g':
    switch (s[1]) {
    case '1':
      return SQ_G1;
    case '2':
      return SQ_G2;
    case '3':
      return SQ_G3;
    case '4':
      return SQ_G4;
    case '5':
      return SQ_G5;
    case '6':
      return SQ_G6;
    case '7':
      return SQ_G7;
    case '8':
      return SQ_G8;
    }
  case 'h':
    switch (s[1]) {
    case '1':
      return SQ_H1;
    case '2':
      return SQ_H2;
    case '3':
      return SQ_H3;
    case '4':
      return SQ_H4;
    case '5':
      return SQ_H5;
    case '6':
      return SQ_H6;
    case '7':
      return SQ_H7;
    case '8':
      return SQ_H8;
    }
  }

  return SQUARE_ZERO;
}

void chess_from_fen(struct Chess *state, char *fen) {
  char *p;
  char buf[2] = {0};
  int file = FILE_A;
  int rank = RANK_8;
  enum Piece piece;

  // Zero out board first
  memset(state->board, 0, 64);
  for (p = fen; *p != ' ' && *p != '\0'; p++) {
    // Next rank
    if (*p == '/') {
      rank--;
      file = 0;
      continue;
    }

    piece = piece_from_char(*p);
    if (piece != NO_PIECE) {
      state->board[rank * 8 + file] = piece;
      file++;
    } else {
      buf[0] = *p;
      file += atoi(buf);
    }
  }

  p++;
  if (*p == 'w')
    state->color = WHITE;
  else
    state->color = BLACK;

  p += 2;
  state->castling_rights = 0;
  for (; *p != ' ' && *p != '\0'; p++) {
    switch (*p) {
    case 'K':
      state->castling_rights |= WHITE_KINGSIDE;
      break;
    case 'Q':
      state->castling_rights |= WHITE_QUEENSIDE;
      break;
    case 'k':
      state->castling_rights |= BLACK_KINGSIDE;
      break;
    case 'q':
      state->castling_rights |= BLACK_QUEENSIDE;
      break;
    }
  }

  p++;
  state->ep_square = square_from_str(p);
}

enum File file_of(enum Square s) { return s & 7; }

enum Rank rank_of(enum Square s) { return s >> 3; }

void chess_print_ascii(struct Chess *state) {
  for (int rank = 7; rank >= 0; rank--) {
    printf(" | ");
    for (int file = 0; file < 8; file++) {
      printf(" %d ", state->board[rank * 8 + file]);
    }
    printf(" |\n");
  }

  printf("Castling rights: %d\n", state->castling_rights);
  printf("Color: %d\n", state->color);
  printf("EP square: %d\n", state->ep_square);
}
