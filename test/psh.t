#!/bin/sh
# Smoke tests for src/psh (Perl REPL). Term::ReadLine needs a controlling
# tty, so the functional tests drive it under a pty allocated by script(1);
# a plain compile check runs unconditionally and needs no tty.
cd "$(dirname "$0")/.." || exit 1
. test/lib/tap.sh

plan 3

# Compiles cleanly and its core modules (Term::ReadLine, Data::Dumper) load.
out=$(perl -c -w src/psh 2>&1)
contains "psh compiles cleanly" "$out" "syntax OK"

if command -v script >/dev/null 2>&1; then
    out=$(printf '42\n' | script -qec 'src/psh' /dev/null 2>/dev/null | tr -d '\r')
    contains "psh evals a literal and prints it" "$out" "42"
    out=$(printf 'show([1,2,3])\n' | script -qec 'src/psh' /dev/null 2>/dev/null | tr -d '\r')
    contains "psh show() runs Data::Dumper" "$out" "VAR1"
else
    skip "psh evals a literal and prints it" "no script(1) to allocate a pty"
    skip "psh show() runs Data::Dumper" "no script(1) to allocate a pty"
fi