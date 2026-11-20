#!/bin/bash
# Build (incrementally) and run doom-fc. `./run.sh --native [args]` uses
# the fcc --native build instead.
set -e
cd "$(dirname "$0")"
if [ "${1:-}" = "--native" ]; then
    shift
    export NATIVE=1
fi
make -s
exec "$(make -s print-bin)" "$@"
