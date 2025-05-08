#!/bin/bash

set -euo pipefail

script_path=$(dirname "$0")
repo_root_path=$(realpath "$script_path/../../../")
start_uci="$repo_root_path/dev_utils/scripts/start-uci.sh"

fastchess_event_name="Fastchess Tournament"
commit_sha=""

# Parse args
while [ "$#" -gt 0 ]; do
  case "$1" in
    --commit-sha) commit_sha="$2"; shift 2;;
    *)            echo "unknown arg"; shift 2;;
  esac
done

if [ -n "$commit_sha" ]; then
  fastchess_event_name="$commit_sha"
fi

# Download binaries
stockfish_bin_url="https://github.com/official-stockfish/Stockfish/releases/download/sf_17.1/stockfish-ubuntu-x86-64.tar"
fastchess_bin_url="https://github.com/Disservin/fastchess/releases/download/v1.4.0-alpha/fastchess-ubuntu-22.04.zip"

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
  unzip -qd "$where" "$tmp_file"
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
mkdir -p "$repo_root_path/results"
"$run_fastchess" \
    -event "$fastchess_event_name" \
    -engine cmd="$start_uci" name=gnomes st=6 \
    -engine cmd="$run_stockfish" name=stockfish depth=24 option.Threads=2 \
    -rounds 3 -repeat -concurrency 6 -maxmoves 75 \
    -pgnout file="$repo_root_path/results/sprt.pgn" \
    -log file="$repo_root_path/results/fastchess.log" level=trace
