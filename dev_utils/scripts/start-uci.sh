#!/bin/bash

set -e

logfile=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --log) logfile="$2"; shift 2 ;;
    *)     echo "usage: $0 [--log <logfile>]"; exit 1;;
  esac
done

cd "$(dirname "$0")"/../../erlang_template
if [ -n "$logfile" ]; then
  # Create temporary named pipes
  tmpdir=$(mktemp -d)
  stdin_pipe="$tmpdir/stdin"
  stdout_pipe="$tmpdir/stdout"
  stderr_pipe="$tmpdir/stderr"

  mkfifo "$stdin_pipe" "$stdout_pipe" "$stderr_pipe"

  echo "$stdin_pipe"

  # Tee stdin to logfile and into program's stdin pipe
  tee -a >(sed 's/^/stdin: /' >> "$logfile") < /dev/stdin > "$stdin_pipe" &

  # Tee stdout and stderr from program to both terminal and logfile
  tee -a >(sed 's/^/stdout: /' >> "$logfile") < "$stdout_pipe" &
  tee -a >(sed 's/^/stderr: /' >> "$logfile") < "$stderr_pipe" &

  gleam run -m erlang_template_uci <"$stdin_pipe" >"$stdout_pipe" 2>"$stderr_pipe"

  # Wait for background processes to finish
  wait
  rm -f "$stdin_pipe" "$stdout_pipe" "$stderr_pipe"
  rmdir "$tmpdir"
else
  gleam run -m erlang_template_uci
fi

