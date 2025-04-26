#!/bin/bash

set -xe

books_dir=""
tables_dir=""
grouped_file=""
combined_table=""

print_help() {
  cat <<EOF
Usage: $0 --books-dir books-dir --tables-dir tables-dir
          --combined-table combined.tbl --grouped-file grouped-file

Tabularizes each book in books-dir combines them into a single table by
deduplicating entries and groups them into a file close to being ready to be
used as a function in a gleam program.

EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --books-dir)      books_dir="$2"; shift 2 ;;
    --tables-dir)     tables_dir="$2"; shift 2 ;;
    --combined-table) combined_table="$2"; shift 2 ;;
    --grouped-file)   grouped_file="$2"; shift 2 ;;
    *) print_help; exit 1 ;;
  esac
done

if [ ! -d "$books_dir" ]; then
  echo "books dir '$books_dir' does not exist"
fi

if [ ! -d "$tables_dir" ]; then
  echo "tables dir '$tables_dir' does not exist"
fi

# Make sure we can actually create these files
touch "$combined_table"
touch "$grouped_file"

cd "$(dirname "$0")"

# First, make the group script
make

for book in "$books_dir"/*.pgn; do
  book_name="$(basename -s .pgn "$book")"
  table="$tables_dir/$book_name.tbl"
  echo "Processing $book into $table"
  deno run tabularize.ts < "$book" | sort | uniq > "$table"
done

# Join them and deduplicate into the combined table
cat "$tables_dir"/*.tbl | sort | uniq > "$combined_table"

# Create the grouped file
./group < "$combined_table" > "$grouped_file"
