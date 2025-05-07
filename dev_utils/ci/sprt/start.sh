#!/bin/bash

set -euo pipefail

script_path=$(dirname "$0")
repo_root_path=$(realpath "$script_path/../../../")
start_uci="$repo_root_path/dev_utils/scripts/start-uci.sh"

stockfish_bin_url="https://github.com/official-stockfish/Stockfish/releases/download/sf_17.1/stockfish-ubuntu-x86-64.tar"
fastchess_bin_url="https://github.com/Disservin/fastchess/releases/download/v1.4.0-alpha/fastchess-ubuntu-22.04.zip"

# Download binaries

download_stockfish() {
  where="$1"
  mkdir -p "$where"
  wget -qO- "$stockfish_bin_url" |\
    tar --strip-components=1 -xC "$where"
}

download_fastchess() {
  where="$1"
  mkdir -p "$where"
  tmp_file=$(mktemp)
  wget -qO "$tmp_file" "$fastchess_bin_url"
  unzip -d "$where" "$tmp_file"
  rm "$tmp_file"
}

# Only download if necessary
[ -d "$repo_root_path/stockfish" ] ||\
  download_stockfish "$repo_root_path/stockfish"
[ -d "$repo_root_path/fastchess" ] ||\
  download_fastchess "$repo_root_path/fastchess"

run_stockfish="$repo_root_path/stockfish/stockfish-ubuntu-x86-64"
run_fastchess="$repo_root_path/fastchess/fastchess-ubuntu-22.04"

# Run fastchess
# TODO: Tune stockfish options
mkdir -p "$repo_root_path/results"
"$run_fastchess" \
    -engine cmd="$start_uci" name=gnomes \
    -engine cmd="$run_stockfish" name=stockfish option.Threads=4 \
    -each st=15 \
    -rounds 2 -repeat -concurrency 1 \
    -pgnout file="$repo_root_path/results/sprt.pgn" \
    -log file="$repo_root_path/results/fastchess.log" level=trace

echo "Log:"
cat "$repo_root_path/results/fastchess.log"

echo "PGN:"
cat "$repo_root_path/results/sprt.pgn"
