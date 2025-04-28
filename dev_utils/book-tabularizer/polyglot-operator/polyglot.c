#include "polyglot.h"
#include "stb_ds.h"

int compare_book_entry(const void *a, const void *b) {
  struct BookEntry *ea = (struct BookEntry *)a;
  struct BookEntry *eb = (struct BookEntry *)b;

  // Compare by key
  if (ea->key < eb->key)
    return -1;
  if (ea->key > eb->key)
    return 1;

  // And then by move
  if (ea->move < eb->move)
    return -1;
  if (ea->move > eb->move)
    return 1;

  return 0;
}

void polyglot_write_dummy_header(FILE *fp) {
  const char zeros[8] = {0};
  char buf[8] = {0};

  // Error checking? Never heard of that

  // As for why this is so retarded, blame the polyglot format.
  // The header would be pretty simple to write, if it weren't for the fact
  // that every 8 bytes, we have to pad 8 zero-bytes.
  //
  // Are there better ways of doing this despite the weirdness? Sure, but
  // doing it like makes it clear what we're doing.
  //
  // Plus, I'm too lazy to change it.

  // 0x0
  fwrite(zeros, 8, 1, fp);
  // 0x8
  strncpy(buf, POLYGLOT_MAGIC, 4);
  fwrite(buf, 4, 1, fp);
  fputc('\x0a', fp);
  strncpy(buf, "1.0", 3);
  fwrite(buf, 3, 1, fp);

  // 0x10
  fwrite(zeros, 8, 1, fp);
  // 0x18
  fputc('\x0a', fp);
  fputc('2', fp); // nbvariants + 1
  fputc('\x0a', fp);
  fputc('1', fp); // nbvariants
  fputc('\x0a', fp);
  strncpy(buf, "nor", 3);
  fwrite(buf, 3, 1, fp);

  // 0x20
  fwrite(zeros, 8, 1, fp);
  // 0x28
  strncpy(buf, "mal", 3);
  fwrite(buf, 3, 1, fp);
  fputc('\x0a', fp);
  strncpy(buf, "Crea", 4);
  fwrite(buf, 4, 1, fp);

  // 0x30
  fwrite(zeros, 8, 1, fp);
  // 0x38
  strncpy(buf, "ted by P", 8);
  fwrite(buf, 8, 1, fp);

  // 0x40
  fwrite(zeros, 8, 1, fp);
  // 0x48
  strncpy(buf, "olyglot.", 8);
  fwrite(buf, 8, 1, fp);

  // 0x50,0x58
  fwrite(zeros, 8, 1, fp);
  fwrite(zeros, 8, 1, fp);
}

int polyglot_read(FILE *fp, struct BookEntry **entries) {
  {
    fseek(fp, 0, SEEK_SET);

    char buf[16];
    size_t n;
    while (1) {
      n = fread(buf, 16, 1, fp);
      if (n != 1) {
        fprintf(stderr, "[error]: fread() failed. bad book?\n");
        return POLYGLOT_ERR;
      }
      // Look for 16 bytes of 0
      if (*(uint64_t *)buf == 0 && *(uint64_t *)(buf + 8) == 0) {
        break;
      }
    }
  }

  struct BookEntry entry;
  size_t n;
  while (1) {
    n = fread(&entry, 16, 1, fp);
    if (n != 1) {
      if (feof(fp)) {
        break;
      } else {
        fprintf(stderr, "[fatal]: fread() failed\n");
        return POLYGLOT_ERR;
      }
    }

    arrput(*entries, entry);
  }

  return POLYGLOT_OK;
}
