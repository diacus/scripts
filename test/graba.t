#!/bin/sh
# Tests for src/graba. Mocks every external tool under $GRABA_PREFIX/bin
# and uses GRABA_WAIT_CHILD so the parent waits for the recording child.
cd "$(dirname "$0")/.." || exit 1
. test/lib/tap.sh
. test/lib/mock.sh

plan 16

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Build the mock tool tree under $GRABA_PREFIX/bin and put it on PATH too
# (for `clear`, which graba invokes via PATH, and `mktemp`, which stays real).
prefix="$tmp/prefix"
bindir="$prefix/bin"
mkdir -p "$bindir"
for t in notify-send xdg-open ffmpeg byzanz-record wf-recorder \
         gdbus hyprctl swaymsg slurp xdotool xwininfo clear; do
    make_mock_bin "$bindir" "$t"
done

# Canned outputs for the tools graba captures.
printf '1234567\n' > "$bindir/xdotool.out"
printf '  Width: 800\n  Height: 600\n  Corners:  +100+50  -1180-730  -100-730  1180+50\n' > "$bindir/xwininfo.out"
printf "(true, '/tmp/graba-test.webm')\n" > "$bindir/gdbus.out"
printf '{"at":[100,50],"size":[800,600]}\n' > "$bindir/hyprctl.out"
printf '{"nodes":[{"nodes":[{"focused":true,"rect":{"x":100,"y":50,"width":800,"height":600}}]}]}\n' > "$bindir/swaymsg.out"
printf '100,200 800x600\n' > "$bindir/slurp.out"

export GRABA_PREFIX="$prefix"
export GRABA_WAIT_CHILD=1
path_prepend "$bindir"

out="$tmp/out.gif"
common="-d 0 -w 0 -o $out"
# wlroots uses an async fork + sleep + SIGINT to stop wf-recorder, so it
# needs a non-zero duration or the parent kills the grandchild before it
# execs the recorder (x11/gnome use synchronous system/capture, -d 0 is fine).
wcommon="-d 1 -w 0 -o $out"

# ---- detection: dies before any tool check, no mocks needed ----
expect_fail "empty session -> non-zero" env -u XDG_SESSION_TYPE src/graba -o "$out"
expect_fail "KDE Wayland -> non-zero" env XDG_SESSION_TYPE=wayland XDG_CURRENT_DESKTOP=KDE src/graba -o "$out"
expect_fail "bogus backend -> non-zero" src/graba --backend bogus -o "$out"

# ---- X11: geometry parsed from mocked xdotool/xwininfo ----
: > "$bindir/byzanz-record.calls"
expect_ok "x11 run -> exit 0" src/graba --backend x11 $common
contains "x11 byzanz called with parsed geometry" \
    "$(calls_of "$bindir" byzanz-record)" "-d 0 -w 800 -h 600 -x 100 -y 50"

# ---- GNOME: gdbus Screencast + StopScreencast, ffmpeg -> GIF ----
: > "$bindir/gdbus.calls"; : > "$bindir/ffmpeg.calls"
expect_ok "gnome run -> exit 0" src/graba --backend gnome $common
gdbus_calls=$(calls_of "$bindir" gdbus)
contains "gnome calls Screencast" "$gdbus_calls" "org.gnome.Shell.Screencast.Screencast"
contains "gnome calls StopScreencast" "$gdbus_calls" "StopScreencast"
contains "gnome ffmpeg palettegen" "$(calls_of "$bindir" ffmpeg)" "palettegen"
contains "gnome ffmpeg paletteuse -> gif" "$(calls_of "$bindir" ffmpeg)" "paletteuse"

# ---- wlroots via hyprctl: geometry from activewindow JSON ----
: > "$bindir/wf-recorder.calls"
expect_ok "wlroots hyprctl run -> exit 0" src/graba --backend wlroots $wcommon
contains "wlroots hyprctl -> wf-recorder -g" \
    "$(calls_of "$bindir" wf-recorder)" "-g 100,50 800x600"

# ---- wlroots via swaymsg (no hyprctl): find_focused rect ----
rm -f "$bindir/hyprctl"
: > "$bindir/wf-recorder.calls"
expect_ok "wlroots swaymsg run -> exit 0" src/graba --backend wlroots $wcommon
contains "wlroots swaymsg -> wf-recorder -g" \
    "$(calls_of "$bindir" wf-recorder)" "-g 100,50 800x600"

# ---- wlroots fallback slurp (no hyprctl, no swaymsg) ----
rm -f "$bindir/swaymsg"
: > "$bindir/wf-recorder.calls"
expect_ok "wlroots slurp fallback -> exit 0" src/graba --backend wlroots $wcommon
contains "wlroots slurp -> wf-recorder -g" \
    "$(calls_of "$bindir" wf-recorder)" "-g 100,200 800x600"