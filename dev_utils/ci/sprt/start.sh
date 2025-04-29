#!/bin/sh

set -xeu

script_path=$(dirname "$0")
robot_path=$(realpath "$script_path/../../../erlang_template")
uci_adapter_path=$(realpath "$script_path/../../uci-adapter")
repo_root_path=$(realpath "$script_path/../../../")

stockfish_bin_url="https://github.com/official-stockfish/Stockfish/releases/download/sf_17.1/stockfish-ubuntu-x86-64-avx2.tar"
fastchess_bin_url="https://github.com/Disservin/fastchess/releases/download/v1.4.0-alpha/fastchess-ubuntu-22.04.zip"

# Download binaries

download_stockfish() {
  where="$1"
  mkdir -p "$where"
  wget -qO- "$stockfish_bin_url" |\
    tar --strip-components=1 -xvC "$where"
}

download_fastchess() {
  where="$1"
  mkdir -p "$where"
  tmp_file=$(mktemp)
  wget -qO "$tmp_file" "$fastchess_bin_url"
  unzip -d "$where" "$tmp_file"
  rm "$tmp_file"
}

download_stockfish "$repo_root_path/stockfish"
download_fastchess "$repo_root_path/fastchess"

run_stockfish="$repo_root_path/stockfish/stockfish-ubuntu-x86-64-avx2"
run_fastchess="$repo_root_path/fastchess/fastchess-ubuntu-22.04"

# Run Gleam bot
cd "$robot_path"
gleam run &
ROBOT_PID="$!"

exit_gracefully() {
  echo "killing robot"
  kill -s KILL "$ROBOT_PID"
  echo "robot reaped"
  exit 0
}

trap exit_gracefully INT
trap exit_gracefully TERM

# Run fastchess
# TODO: Tune stockfish options
mkdir -p "$repo_root_path/results"
"$run_fastchess" \
    -engine cmd="$uci_adapter_path/start.sh" name=gnomes st=8 \
    -engine cmd="$run_stockfish" name=stockfish st=5 'option.Skill Level=1' \
    -rounds 1 -repeat -concurrency 1 \
    -pgnout file="$repo_root_path/results/sprt.pgn" \
    -log file="$repo_root_path/results/fastchess.log"

exit_gracefully
