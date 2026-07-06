# Mock helpers for tests. Source from a .t file.

# new_mock_dir : echo a fresh temp dir for mock binaries
new_mock_dir () {
    mktemp -d
}

# path_prepend DIR : prepend DIR to PATH (export)
path_prepend () {
    PATH="$1:$PATH"; export PATH
}

# make_mock_bin DIR NAME
# Creates DIR/NAME, an executable mock that on each invocation:
#   - appends its argv (one line, space-joined) to DIR/NAME.calls
#   - prints DIR/NAME.out if it exists
#   - exits with the value in DIR/NAME.exit if it exists, else 0
make_mock_bin () {
    _mb_dir="$1"; _mb_name="$2"
    mkdir -p "$_mb_dir"
    cat > "$_mb_dir/$_mb_name" <<EOF
#!/bin/sh
printf '%s\\n' "\$*" >> "$_mb_dir/$_mb_name.calls"
[ -f "$_mb_dir/$_mb_name.out" ] && cat "$_mb_dir/$_mb_name.out"
if [ -f "$_mb_dir/$_mb_name.exit" ]; then
    exit "\$(cat "$_mb_dir/$_mb_name.exit")"
fi
exit 0
EOF
    chmod +x "$_mb_dir/$_mb_name"
}

# calls_of DIR NAME : print recorded invocations (one per line)
calls_of () {
    [ -f "$1/$2.calls" ] && cat "$1/$2.calls" || true
}