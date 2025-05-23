#!/bin/bash

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [--tag tag] [-- ...docker args]

  Run the chess bot docker image in UCI at a specific tag. Use -- to delimit
  args to pass into the docker run command.

EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --tag) tag="$2"; shift 2 ;;
    --)    shift; break ;;
    *)     usage; exit 1     ;;
  esac
done

tag=${tag:-latest}
docker_args=$@

# Get this command by inspecting the entrypoint.sh referenced in the Dockerfile
# And then modify it to run the UCI entrypoint to get this command.
# Make sure not to use -t here; it breaks for things like fastchess
docker run \
  --rm -i \
  --entrypoint=/bin/sh \
  $docker_args \
  "ghcr.io/tonyd33/gleam-chess-tournament/chess-bot:$tag" \
  -c 'erl -pa /app/*/ebin -eval "erlang_template@@main:run(erlang_template_uci)" -noshell -extra'
