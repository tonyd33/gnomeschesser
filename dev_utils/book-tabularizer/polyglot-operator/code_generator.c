#include "code_generator.h"
#include "polyglot.h"
#include "stb_ds.h"
#include <stdio.h>
#include <stdlib.h>

int generate(FILE *ifp, FILE *ofp) {
  // Read all the entries and sort them by key.
  struct BookEntry *entries = NULL;
  if (polyglot_read(ifp, &entries) != POLYGLOT_OK) {
    arrfree(entries);
    return GENERATOR_ERR;
  }

  if (arrlen(entries) == 0) {
    fprintf(stderr, "[error]: didn't read any entries\n");
    arrfree(entries);
    return GENERATOR_ERR;
  }

  qsort(entries, arrlen(entries), sizeof(struct BookEntry),
        compare_book_entry);

  // Generate code by grouping them
  {
    uint64_t group_key = entries[0].key;

    fprintf(ofp, "pub fn move_lookup(x) {\n");
    fprintf(ofp, "case x {\n");
    struct BookEntry *group_entries = NULL;
    for (int i = 0; i < arrlen(entries); i++) {
      if (entries[i].key != group_key) {
        // New group. Emit the current group and set new group
        fprintf(ofp, "0x%llx->[", group_key);
        for (int j = 0; j < arrlen(group_entries); j++) {
          fprintf(ofp, "0x%x", group_entries[j].move);
          if (j != arrlen(group_entries) - 1) {
            fprintf(ofp, ",");
          }
        }
        fprintf(ofp, "]\n");

        arrfree(group_entries);
        group_key = entries[i].key;
      }

      // Append to group
      arrput(group_entries, entries[i]);
    }
    fprintf(ofp, "}\n"); // case
    fprintf(ofp, "}\n"); // function

    arrfree(group_entries);
  }

  arrfree(entries);
  return GENERATOR_OK;
}
