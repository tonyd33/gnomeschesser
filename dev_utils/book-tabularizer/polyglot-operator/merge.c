#include "merge.h"
#include "polyglot.h"
#include "stb_ds.h"
#include <assert.h>

struct Cursor {
  struct BookEntry *entries;
  int size;
  int index;
};

int find_min_idx(struct Cursor cursors[], int k) {
  uint64_t min_val = UINT64_MAX;

  int min_idx = -1;
  for (int i = 0; i < k; ++i) {
    if (cursors[i].index < cursors[i].size) {
      if (cursors[i].entries[cursors[i].index].key < min_val) {
        min_val = cursors[i].entries[cursors[i].index].key;
        min_idx = i;
      }
    }
  }
  return min_idx;
}

int merge(FILE **books, int k, FILE *ofp) {
  struct BookEntry *entries_arr[k];
  // have to zero these guys out for stb_ds
  memset(entries_arr, 0, sizeof(struct BookEntry *) * k);

  struct Cursor cursors[k];
  int total_entries = 0;

  // Read the books and sort them
  for (int i = 0; i < k; i++) {
    if (polyglot_read(books[i], &entries_arr[i]) != POLYGLOT_OK) {
      fprintf(stderr, "[error]: failed reading a book\n");
      return MERGE_ERR;
    }

    int len = arrlen(entries_arr[i]);
    total_entries += len;
    qsort(entries_arr[i], len, sizeof(struct BookEntry),
          compare_book_entry);

    cursors[i].entries = entries_arr[i];
    cursors[i].size = len;
    cursors[i].index = 0;
  }

  // Write a header
  polyglot_write_dummy_header(ofp);

  // Perform the k-way merge
  // TODO: Deduplicate by moves too
  int min_idx;
  for (int i = 0; i < total_entries; i++) {
    min_idx = find_min_idx(cursors, k);
    assert(min_idx != -1);

    struct BookEntry be = cursors[min_idx].entries[cursors[min_idx].index];
    fwrite(&be, sizeof(struct BookEntry), 1, ofp);
    cursors[min_idx].index++;
  }

  for (int i = 0; i < k; i++) {
    arrfree(entries_arr[i]);
  }
  return MERGE_OK;
}
