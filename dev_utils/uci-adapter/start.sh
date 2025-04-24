#!/bin/sh

set -e

DIR=$(dirname "$0")
cd "$DIR"
exec deno run --allow-all app/main.ts
