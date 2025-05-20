#!/bin/bash

set -euo pipefail

# This is such a pain on MacOS because realpath doesn't resolve correctly if
# the file doesn't exist already!
resolve_path() {
    input="$1"

    # Extract absolute directory part, even if it doesn't exist
    dir_part=$(dirname "$input")
    file_part=$(basename "$input")

    # Resolve directory to an absolute path
    abs_dir=$(cd "$dir_part" 2>/dev/null && pwd -P || echo "$(pwd -P)/$dir_part")

    # Return combined absolute path
    echo "$abs_dir/$file_part"
}

# Thank you https://stackoverflow.com/a/1403489
apply_suffix() {
  fullpath="$1"
  suffix="$2"

  filename="${fullpath##*/}"                      # Strip longest match of */ from start
  dir="${fullpath:0:${#fullpath} - ${#filename}}" # Substring from 0 thru pos of filename
  base="${filename%.[^.]*}"                       # Strip shortest match of . plus at least one non-dot char from end
  ext="${filename:${#base} + 1}"                  # Substring from len of base thru end

  echo "$dir$base-$suffix.$ext"
}

logwrap_dir=$(realpath "$(dirname "$0")/../logwrap/")
engine_dir="$(realpath "$(dirname "$0")/../../erlang_template")"
logfile=""
suffix=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --log)           logfile=$(resolve_path "$2"); shift 2;;
    --random-suffix) suffix=$(openssl rand -hex 4); shift;;
    *)               echo "usage: $0 [--log <logfile>]"; exit 1;;
  esac
done

if [ -n "$logfile" ]; then
  # Apply suffix
  logfile=$(apply_suffix "$logfile" "$suffix")
  echo "$logfile"

  # Compile logwrap
  cd "$logwrap_dir"
  make

  # Run engine
  cd "$engine_dir"
  exec "$logwrap_dir/src/logwrap" \
    "$logfile" \
    gleam run -m erlang_template_uci
else
  cd "$engine_dir"
  exec gleam run -m erlang_template_uci
fi

