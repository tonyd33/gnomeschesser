#define STB_DS_IMPLEMENTATION
#include "stb_ds.h"

#include "code_generator.h"
#include "merge.h"
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

enum Operation { OPERATION_UNKNOWN, OPERATION_GENERATE, OPERATION_MERGE };

struct Options {
  enum Operation operation;

  /* For generate operation */
  char polyglot_file[512];

  /* For merge operation */
  char polyglot_files[64][512];
  int polyglot_file_count;
  char output_file[512];
};

void print_usage(char *progname) {
  fprintf(stderr, "Usage: %s operation [arguments...]\n", progname);
  fprintf(stderr, "Operations:\n");
  fprintf(stderr, "  codegen polyglot-file             Generates code\n");
  fprintf(stderr,
          "  merge   [polyglot-file ...]       Merges polyglot files\n");
  fprintf(stderr, "          [--output,-o output-file]\n");
  fprintf(stderr, "\n");
}

void parse_args(struct Options *options, int argc, char **argv) {
  options->operation = OPERATION_UNKNOWN;

  if (argc < 2) {
    print_usage(argv[0]);
    exit(EXIT_FAILURE);
  }

  if (strcmp(argv[1], "codegen") == 0) {
    options->operation = OPERATION_GENERATE;
    if (argc < 3) {
      print_usage(argv[0]);
      fprintf(stderr, "Missing positional argument(s)\n");
      exit(EXIT_FAILURE);
    }
    strncpy(options->polyglot_file, argv[2], 512);
  } else if (strcmp(argv[1], "merge") == 0) {
    options->operation = OPERATION_MERGE;
    if (argc < 4) {
      print_usage(argv[0]);
      fprintf(stderr, "Missing positional argument(s)\n");
      exit(EXIT_FAILURE);
    }
    options->polyglot_file_count = 0;

    for (int i = 2; i < argc; i++) {
      if (strcmp(argv[i], "--output") == 0 || strcmp(argv[i], "-o") == 0) {
        if (i + 1 >= argc) {
          print_usage(argv[0]);
          fprintf(stderr, "Missing positional argument after --into\n");
          exit(EXIT_FAILURE);
        }

        strncpy(options->output_file, argv[++i], 512);
      } else {
        strncpy(options->polyglot_files[options->polyglot_file_count++],
                argv[i], 512);
      }
    }
  } else {
    print_usage(argv[0]);
    exit(EXIT_FAILURE);
  }
}

int main(int argc, char **argv) {
  struct Options options = {0};
  parse_args(&options, argc, argv);

  switch (options.operation) {
  case OPERATION_GENERATE: {
    fprintf(stderr, "Running on polyglot file %s\n", options.polyglot_file);
    FILE *fp = fopen(options.polyglot_file, "rb");
    if (!fp) {
      perror("fopen");
      exit(EXIT_FAILURE);
    }

    generate(fp, stdout);
    fclose(fp);

    break;
  }
  case OPERATION_MERGE: {
    FILE *fps[64];

    for (int i = 0; i < options.polyglot_file_count; i++) {
      fps[i] = fopen(options.polyglot_files[i], "rb");
      if (!fps[i]) {
        perror("fopen");
        fprintf(stderr, "Could not open %s", options.polyglot_files[i]);
        exit(EXIT_FAILURE);
      }
    }

    FILE *output = stdout;

    if (strcmp(options.output_file, "") != 0) {
      output = fopen(options.output_file, "wb");
      if (!output) {
        fprintf(stderr, "Could not open %s", options.output_file);
        perror("fopen");
        exit(EXIT_FAILURE);
      }
    }
    merge(fps, options.polyglot_file_count, output);

    for (int i = 0; i < options.polyglot_file_count; i++) {
      fclose(fps[i]);
    }
    fclose(output);

    break;
  }
  case OPERATION_UNKNOWN:
  default:
    fprintf(stderr, "Unknown operation '%s'\n", argv[1]);
    return 1;
  }

  return 0;
}
