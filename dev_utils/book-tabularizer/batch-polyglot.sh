#!/bin/bash

set -xeuo pipefail

books_dir=""
polyglot_dir=""
merged_file=""
code_file=""

print_help() {
  cat <<EOF
Usage: $0 --books-dir books-dir --polyglot-dir polyglot-dir
          --merged-file file --code-file file

EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --books-dir)      books_dir="$2"; shift 2 ;;
    --polyglot-dir)   polyglot_dir="$2"; shift 2 ;;
    --merged-file)    merged_file="$2"; shift 2 ;;
    --code-file)      code_file="$2"; shift 2 ;;
    *) print_help; exit 1 ;;
  esac
done

if [ ! -d "$books_dir" ]; then
  echo "books dir '$books_dir' does not exist"
fi

if [ ! -d "$polyglot_dir" ]; then
  echo "tables dir '$polyglot_dir' does not exist"
fi

# Ensure we can create these files
touch "$merged_file"
touch "$code_file"

cd "$(dirname "$0")"

make all

polyglot_files=()

for book in "$books_dir"/*.pgn; do
  book_name="$(basename -s .pgn "$book")"
  polyglot_file="$polyglot_dir/$book_name.bin"
  polyglot_files+=("$polyglot_file")

  echo "Processing $book into $polyglot_file"
  build/polyglot MakeBook -pgn "$book" -bin "$polyglot_file"
done


build/polyglot-operator merge "${polyglot_files[@]}" --output "$merged_file"
build/polyglot-operator codegen "$merged_file" > "$code_file"
