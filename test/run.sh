#!/bin/sh
# Run the test suite against the source tree (no install needed).
# Usage: sh test/run.sh [prove args]
#   sh test/run.sh        # default
#   sh test/run.sh -v     # verbose TAP
cd "$(dirname "$0")/.." || exit 1
exec prove "$@" test/*.t