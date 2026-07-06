#!/bin/sh
# Tests for src/set-static-ipv4. Mocks nmcli on PATH.
cd "$(dirname "$0")/.." || exit 1
. test/lib/tap.sh
. test/lib/mock.sh

plan 14

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mdir="$tmp/mocks"; mkdir -p "$mdir"
path_prepend "$mdir"

export NMCLI_CALLS="$tmp/nmcli.calls"
NMCLI_CONNS="$tmp/conns"; export NMCLI_CONNS

# nmcli mock: records every call; "connection show" prints the canned list.
cat > "$mdir/nmcli" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >> "$NMCLI_CALLS"
case "$*" in
    *"connection show"*) cat "$NMCLI_CONNS" ;;
esac
exit 0
EOF
chmod +x "$mdir/nmcli"

modify_calls () { grep -c 'connection modify' "$NMCLI_CALLS" 2>/dev/null; }
reset_calls () { : > "$NMCLI_CALLS"; }

# 1-2: argument validation
expect_exit "no args -> exit 1" 1 sh src/set-static-ipv4
expect_exit "one arg -> exit 1" 1 sh src/set-static-ipv4 192.168.1.5

# 3-4: no connection matches the pattern
printf 'Other\nWork\n' > "$NMCLI_CONNS"
reset_calls
expect_exit "no matching connection -> exit 1" 1 sh src/set-static-ipv4 192.168.1.5 'TESTSSID*'
err=$(sh src/set-static-ipv4 192.168.1.5 TESTSSID 2>&1 >/dev/null)
contains "no-match stderr mentions no connection matched" "$err" "no connection matched"

# 5-6: one exact match -> correct nmcli modify invocation
printf 'TESTSSID\nOther\n' > "$NMCLI_CONNS"
reset_calls
expect_ok "one exact match -> exit 0" sh src/set-static-ipv4 192.168.1.5 TESTSSID
is "one match -> 1 modify call" "$(modify_calls)" "1"
mc=$(grep 'connection modify' "$NMCLI_CALLS" | head -1)
contains "modify args correct" "$mc" \
    "connection modify TESTSSID ipv4.method manual ipv4.addresses 192.168.1.5/24 ipv4.gateway 192.168.100.1 ipv4.dns 192.168.100.2 ipv6.ignore-auto-dns yes ipv6.dns 2806:2f0:5341:f465:26aa:1dfa:32f9:92f4"

# 7-10: glob TESTSSID* matches TESTSSID and TESTSSID-5G, not Other
printf 'TESTSSID\nTESTSSID-5G\nOther\n' > "$NMCLI_CONNS"
reset_calls
expect_ok "glob run -> exit 0" sh src/set-static-ipv4 10.0.0.5 'TESTSSID*'
is "glob -> 2 modify calls" "$(modify_calls)" "2"
all=$(grep 'connection modify' "$NMCLI_CALLS")
contains "glob matched TESTSSID" "$all" "modify TESTSSID "
contains "glob matched TESTSSID-5G" "$all" "modify TESTSSID-5G "
case "$all" in *"modify Other"*) _res=present ;; *) _res=absent ;; esac
is "glob did not match Other" "$_res" absent

# 11: pattern * matches all connections
printf 'A\nB\nC\n' > "$NMCLI_CONNS"
reset_calls
expect_ok "star matches all -> exit 0" sh src/set-static-ipv4 10.0.0.5 '*'
is "star -> 3 modify calls" "$(modify_calls)" "3"
