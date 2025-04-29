#ifndef _POLYGLOT_H_
#define _POLYGLOT_H_

#include <vector>
#include <stdint.h>

using namespace std;

struct BookEntry {
  uint64_t key;
  uint16_t move;
  uint16_t weight;
  uint32_t learn;

  bool operator<(const BookEntry &be) const;
};
static_assert(sizeof(struct BookEntry) == 16);

vector<struct BookEntry> read_pg_file(ifstream &strm);

void write_pg_file(ostream &strm, vector<struct BookEntry> &entries);

/*
 * Entries with the same key and move should "combine" and join weights.
 * Assumes `entries` is already sorted.
 */
vector<struct BookEntry>
reduce_to_normal_form(vector<struct BookEntry> &entries);

#endif /* _POLYGLOT_H_ */
