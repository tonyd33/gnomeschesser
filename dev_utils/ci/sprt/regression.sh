#!/bin/sh

set -eu

working_dir=$(pwd)
script_path=$(dirname "$0")
repo_root_path=$(realpath "$script_path/../../../")
run_challenger="$repo_root_path/dev_utils/scripts/start-docker-uci.sh"
run_defender="$repo_root_path/dev_utils/scripts/start-docker-uci.sh"
# TODO: Constrain resources again once we properly manage memory
# challenger_args="--tag local -- -m 500M --cpus 2"
# defender_args="--tag latest -- -m 500M --cpus 2"
challenger_args="--tag local"
defender_args="--tag latest"
logwrap_dir=$(realpath "$(dirname "$0")/../../logwrap/")

fastchess_event_name="Fastchess Tournament"
rounds=8
# run (half #cores - 2) games at a time.
# yes, we're piping into deno just for this. yes, it's cursed
concurrency=$(echo "Math.min(($(nproc)/2) - 2)" | NO_COLOR=1 deno repl -q)
games=2
results_dir="$repo_root_path/results"
st=3
pull=yes
build=yes
book="$repo_root_path/opening_books/8moves_v3.pgn"
system=$(uname -sm)

case "$system" in
  "Darwin arm64")
    fastchess_bin_url="https://github.com/Disservin/fastchess/releases/download/v1.4.0-alpha/fastchess-macos-latest.zip"
    ;;
  "Linux x86_64")
    fastchess_bin_url="https://github.com/Disservin/fastchess/releases/download/v1.4.0-alpha/fastchess-ubuntu-22.04.zip"
    ;;
  *) echo "unknown system: $system"; exit 1;;
esac

usage() {
  cat <<EOF
Usage:
  $0 [options...]

Options:
  --rounds          rounds      rounds to be played. default $rounds
  --games           games       number of games per round. default $games
  --concurrency     concurrency # of games to be played at the same time. default $concurrency
  --challenger      cmd         command to start challenger engine. default $run_challenger
  --challenger-args args        args to pass into the challenger engine
  --defender        cmd         command to start defender engine. default $run_defender
  --defender-args   args        args to pass into the defender engine
  --results         dir         directory to store results. default $results_dir
  --st              sec         seconds per move. default $st
  --no-pull                     don't pull latest docker image
  --no-build                    don't build current docker image

EOF
}

# Parse args
while [ "$#" -gt 0 ]; do
  case "$1" in
    --event-name)      fastchess_event_name="$2"; shift 2;;
    --rounds)          rounds="$2"; shift 2;;
    --games)           games="$2"; shift 2;;
    --concurrency)     concurrency="$2"; shift 2;;
    --challenger)      run_challenger=$(realpath "$working_dir/$2"); shift 2;;
    --challenger-args) challenger_args="$2"; shift 2;;
    --defender)        run_defender=$(realpath "$working_dir/$2"); shift 2;;
    --defender-args)   defender_args="$2"; shift 2;;
    --no-pull)         pull=no; shift;;
    --no-build)        build=no; shift;;
    --st)              st="$2" shift 2;;
    *)                 usage; exit 1;
  esac
done


cat <<EOF >&2
Running with options:

fastchess_event_name="$fastchess_event_name"
rounds="$rounds"
concurrency="$concurrency"
challenger="$run_challenger"
defender="$run_defender"
results_dir="$results_dir"
st="$st"
pull="$pull"
build="$build"
book="$book"
system="$system"

EOF

# TODO: this should really be made into a separate script to keep in sync with
# stockfish.sh
download_fastchess() {
  where="$1"
  mkdir -p "$where"
  tmp_file=$(mktemp)
  wget -qO "$tmp_file" "$fastchess_bin_url"
  unzip -qd "$where" "$tmp_file"
  rm "$tmp_file"
}

[ -d "$repo_root_path/fastchess" ] ||\
  download_fastchess "$repo_root_path/fastchess"

run_fastchess=$(ls "$repo_root_path"/fastchess/fastchess-*)

if [ "$pull" = yes ]; then
  docker pull ghcr.io/tonyd33/gleam-chess-tournament/chess-bot:latest
fi

if [ "$build" = yes ]; then
  docker build \
    -t ghcr.io/tonyd33/gleam-chess-tournament/chess-bot:local \
    -f "$repo_root_path/erlang_template/Dockerfile" \
    "$repo_root_path/erlang_template"
fi

# Compile logwrap
cd "$logwrap_dir"
make
cd -

# Run fastchess
mkdir -p "$results_dir"
"$run_fastchess" \
    -event "$fastchess_event_name" \
    -engine \
      cmd="$run_defender" \
      args="$defender_args" \
      name=defender \
    -engine \
      cmd="$run_challenger" \
      args="$challenger_args" \
      name=challenger \
    -each st="$st" \
    -rounds "$rounds" -games "$games" -concurrency "$concurrency" -maxmoves 100 \
    -pgnout file="$results_dir/regression.pgn" \
    -log file="$results_dir/fastchess-regression.log" level=trace \
    -openings file="$book" format=pgn order=random
