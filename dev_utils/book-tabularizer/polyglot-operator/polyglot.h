#ifndef _BOOK_H_
#define _BOOK_H_

#include <stdint.h>
#include <stdio.h>

#define POLYGLOT_OK 0
#define POLYGLOT_ERR (-1)

#define POLYGLOT_MAGIC "@PG@"

struct BookEntry {
  uint64_t key;
  uint16_t move;
  uint16_t weight;
  uint32_t learn;
}; /* Should be 16 bytes */

int compare_book_entry(const void *a, const void *b);

void polyglot_write_dummy_header(FILE *fp);

int polyglot_read(FILE* fp, struct BookEntry *entries[]);

#endif /* _BOOK_H_ */
