#!/bin/bash

set -euo pipefail

working_dir=$(pwd)
script_path=$(dirname "$0")
repo_root_path=$(realpath "$script_path/../../../")
start_uci="$repo_root_path/dev_utils/scripts/start-uci.sh"

fastchess_event_name="Fastchess Tournament"
rounds=6
# run (half #cores - 2) games at a time.
# yes, we're piping into deno just for this. yes, it's cursed
concurrency=$(echo "Math.max(($(nproc)/2) - 2, 1)" | NO_COLOR=1 deno repl -q)
games=1
stockfish_skill_level=20
stockfish_depth=24
engine_cmd="$start_uci"
results_dir="$repo_root_path/results"
system=$(uname -sm)

case "$system" in
  "Darwin arm64")
    stockfish_bin_url="https://github.com/official-stockfish/Stockfish/releases/download/sf_17.1/stockfish-macos-m1-apple-silicon.tar"
    fastchess_bin_url="https://github.com/Disservin/fastchess/releases/download/v1.4.0-alpha/fastchess-macos-latest.zip"
    ;;
  "Linux x86_64")
    stockfish_bin_url="https://github.com/official-stockfish/Stockfish/releases/download/sf_17.1/stockfish-ubuntu-x86-64.tar"
    fastchess_bin_url="https://github.com/Disservin/fastchess/releases/download/v1.4.0-alpha/fastchess-ubuntu-22.04.zip"
    ;;
  *) echo "unknown system: $system"; exit 1;;
esac


usage() {
  cat <<EOF
Usage:
  $0 [options...]

Options:
  --rounds      rounds      rounds to be played. default $rounds
  --games       games       number of games per round. default $games
  --concurrency concurrency # of games to be played at the same time. default $concurrency
  --sf-skill    skill       stockfish skill. 0-20. default $stockfish_skill_level
  --sf-depth    depth       stockfish search depth. default $stockfish_depth
  --engine-cmd  cmd         command to start our engine. default $engine_cmd
  --results     dir         directory to store results. default $results_dir

EOF
}

# Parse args
while [ "$#" -gt 0 ]; do
  case "$1" in
    --event-name)  fastchess_event_name="$2"; shift 2;;
    --rounds)      rounds="$2"; shift 2;;
    --games)       games="$2"; shift 2;;
    --concurrency) concurrency="$2"; shift 2;;
    --sf-skill)    stockfish_skill_level="$2"; shift 2;;
    --sf-depth)    stockfish_depth="$2"; shift 2;;
    --engine-cmd)  engine_cmd="$(realpath "$working_dir/$2")"; shift 2;;
    *)             usage; exit 1;
  esac
done

cat <<EOF >&2
Running with options:

fastchess_event_name="$fastchess_event_name"
rounds="$rounds"
concurrency="$concurrency"
stockfish_skill_level="$stockfish_skill_level"
stockfish_depth="$stockfish_depth"
engine_cmd="$engine_cmd"
results_dir="$results_dir"
system="$system"

EOF

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

run_stockfish=$(ls "$repo_root_path"/stockfish/stockfish-*)
run_fastchess=$(ls "$repo_root_path"/fastchess/fastchess-*)

# Run fastchess
mkdir -p "$results_dir"
"$run_fastchess" \
    -event "$fastchess_event_name" \
    -engine \
      cmd="$start_uci" \
      name=gnomes \
      st=6 \
    -engine \
      cmd="$run_stockfish" \
      name=stockfish \
      depth="$stockfish_depth" \
      option.Threads=2 \
      "option.Skill Level=$stockfish_skill_level" \
    -rounds "$rounds" -games "$games" -concurrency "$concurrency" -maxmoves 100 \
    -pgnout file="$results_dir/stockfish.pgn" \
    -log file="$results_dir/fastchess-stockfish.log" level=trace
