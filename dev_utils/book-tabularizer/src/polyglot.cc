#include "polyglot.h"
#include "util.h"
#include <fstream>

bool BookEntry::operator<(const BookEntry &be) const {
  if (key != be.key)
    return key < be.key;
  else
    return move < be.move;
}

vector<struct BookEntry> read_pg_file(ifstream &strm) {
  // Look for 16 bytes of 0
  char buf[16];
  while (1) {
    strm.read(buf, 16);
    if (*(uint64_t *)buf == 0 && *(uint64_t *)(buf + 8) == 0) {
      break;
    }
  }

  vector<struct BookEntry> entries;
  struct BookEntry be;
  while (!strm.eof()) {
    strm.read((char *)&be, sizeof(struct BookEntry));
    entries.push_back(be);
  }

  return entries;
}

void write_pg_file(ostream &strm, vector<struct BookEntry> &entries) {
  // Write header
  {
    const char zeros[8] = {0};
    // 0x0-0x10
    strm.write(zeros, 8);
    strm.write("@PG@", 4);
    strm.write("\x0a", 1);
    strm.write("1.0", 3);

    // 0x10-0x20
    strm.write(zeros, 8);
    strm.write("\x0a", 1);
    strm.write("2", 1); // nbvariants + 1
    strm.write("\x0a", 1);
    strm.write("1", 1); // nbvariants
    strm.write("\x0a", 1);
    strm.write("nor", 3);

    // 0x20-0x30
    strm.write(zeros, 8);
    strm.write("mal", 3);
    strm.write("\x0a", 1);
    strm.write("Crea", 4);

    // 0x30-0x40
    strm.write(zeros, 8);
    strm.write("ted by P", 8);

    // 0x40-0x50
    strm.write(zeros, 8);
    strm.write("olyglot.", 8);

    // 0x50-0x60
    strm.write(zeros, 8);
    strm.write(zeros, 8);
  }

  for (const struct BookEntry &be : entries) {
    auto key = swap64(be.key);
    auto move = swap16(be.move);
    auto weight = swap16(be.weight);
    auto learn = swap32(be.learn);
    strm.write((char *)&key, 8);
    strm.write((char *)&move, 2);
    strm.write((char *)&weight, 2);
    strm.write((char *)&learn, 4);
  }
}

vector<struct BookEntry>
reduce_to_normal_form(vector<struct BookEntry> &entries) {
  vector<struct BookEntry> reduced_entries;
  if (entries.size() == 0) {
    return reduced_entries;
  }

  struct BookEntry &curr_be = entries[0];
  for (auto it = entries.begin() + 1; it != entries.end(); it++) {
    const struct BookEntry &be = *it;

    if (curr_be.key == be.key && curr_be.move == be.move) {
      curr_be.weight += 1;
    } else {
      reduced_entries.push_back(curr_be);
      curr_be = be;
    }
  }
  // Don't forget the last one
  reduced_entries.push_back(curr_be);

  return reduced_entries;
}
