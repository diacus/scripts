#!/bin/sh
# Tests for src/laptop-keyboard (X11 with mocked xinput, Wayland via the
# LAPTOP_KB_* env hooks against a synthetic /proc + sysfs tree).
cd "$(dirname "$0")/.." || exit 1
. test/lib/tap.sh
. test/lib/mock.sh

plan 11

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mdir="$tmp/mocks"; mkdir -p "$mdir"
path_prepend "$mdir"
make_mock_bin "$mdir" xinput

# ---- X11 path: pre-seed the descriptor so xinput list is not needed ----
desc="$tmp/descriptor"
printf '5:3\n' > "$desc"
export LAPTOP_KB_DESCRIPTOR="$desc"

expect_ok "x11 off -> exit 0" sh src/laptop-keyboard --backend x11 off
is "x11 off calls xinput float 5" "$(calls_of "$mdir" xinput)" "float 5"

: > "$mdir/xinput.calls"
expect_ok "x11 on -> exit 0" sh src/laptop-keyboard --backend x11 on
is "x11 on calls xinput reattach 5 3" "$(calls_of "$mdir" xinput)" "reattach 5 3"

# ---- Wayland path: synthetic /proc/bus/input/devices + sysfs tree ----
devices="$tmp/devices"
printf 'N: Name="AT Translated Set 2 keyboard"\nS: Sysfs=/fake/input/input3\n\n' > "$devices"
sysroot="$tmp/sys"
inhibited="$sysroot/fake/input/input3/inhibited"
mkdir -p "$(dirname "$inhibited")"
: > "$inhibited"
cache="$tmp/cache"
export LAPTOP_KB_DEVICES="$devices" LAPTOP_KB_SYSROOT="$sysroot" LAPTOP_KB_CACHE="$cache"

rm -f "$cache"; printf '0\n' > "$inhibited"
expect_ok "wayland off -> exit 0" sh src/laptop-keyboard --backend wayland off
is "wayland off writes 1 to inhibited" "$(cat "$inhibited")" "1"
is "wayland off caches the path" "$(cat "$cache")" "$inhibited"

printf '1\n' > "$inhibited"
expect_ok "wayland on -> exit 0" sh src/laptop-keyboard --backend wayland on
is "wayland on writes 0 to inhibited" "$(cat "$inhibited")" "0"

# ---- backend resolution ----
expect_exit "bogus backend -> exit 2" 2 sh src/laptop-keyboard --backend bogus off
expect_fail "empty session -> non-zero" env -u XDG_SESSION_TYPE sh src/laptop-keyboard off