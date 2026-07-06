#!/bin/sh
# Tests for src/set-gdm-avatar. Uses ACCOUNTSSERVICE_DIR + mocked
# getent/id/install so it runs unprivileged without touching /var/lib.
cd "$(dirname "$0")/.." || exit 1
. test/lib/tap.sh
. test/lib/mock.sh

plan 9

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mdir="$tmp/mocks"; mkdir -p "$mdir"
path_prepend "$mdir"

# getent mock: getent passwd <user> prints a passwd line with $GETENT_HOME.
cat > "$mdir/getent" <<'EOF'
#!/bin/sh
[ "$1" = "passwd" ] && [ "$2" = "fakeuser" ] &&
    printf 'fakeuser:x:1000:1000::%s:/bin/sh\n' "$GETENT_HOME"
exit 0
EOF
# id mock: fakeuser exists, anyone else does not.
cat > "$mdir/id" <<'EOF'
#!/bin/sh
[ "$1" = "fakeuser" ] && exit 0
exit 1
EOF
# install mock: ignore mode/owner flags, copy the last-but-one arg to the
# last arg (the script always passes SRC then DST as the final positionals).
cat > "$mdir/install" <<'EOF'
#!/bin/sh
prev=; last=
for a in "$@"; do prev="$last"; last="$a"; done
mkdir -p "$(dirname "$last")"
cp "$prev" "$last"
EOF
chmod +x "$mdir/getent" "$mdir/id" "$mdir/install"

# Fresh AccountsService tree for every case.
fresh_as () {
    as_dir="$tmp/as.$1"; rm -rf "$as_dir"
    mkdir -p "$as_dir/icons" "$as_dir/users"
    export ACCOUNTSSERVICE_DIR="$as_dir"
}

# 1-2: valid user, no prior users file -> [User] + Icon created
fresh_as 1
home="$tmp/home1"; mkdir -p "$home"; printf 'face\n' > "$home/.face"
export GETENT_HOME="$home"
expect_ok "valid user -> exit 0" sh src/set-gdm-avatar fakeuser
uf="$ACCOUNTSSERVICE_DIR/users/fakeuser"
is "users file has [User] and Icon" "$(cat "$uf")" "[User]
Icon=$ACCOUNTSSERVICE_DIR/icons/fakeuser"

# 3-4: prior users file with an old Icon= -> replaced
fresh_as 2
home="$tmp/home2"; mkdir -p "$home"; printf 'face\n' > "$home/.face"
export GETENT_HOME="$home"
uf="$ACCOUNTSSERVICE_DIR/users/fakeuser"
printf '[User]\nIcon=/old/path\n' > "$uf"
expect_ok "replace old Icon -> exit 0" sh src/set-gdm-avatar fakeuser
content=$(cat "$uf")
contains "new Icon points to AccountsService" "$content" "Icon=$ACCOUNTSSERVICE_DIR/icons/fakeuser"
case "$content" in *"/old/path"*) _r=present ;; *) _r=absent ;; esac
is "old Icon removed" "$_r" absent

# 5: prior users file -> backup created
fresh_as 3
home="$tmp/home3"; mkdir -p "$home"; printf 'face\n' > "$home/.face"
export GETENT_HOME="$home"
uf="$ACCOUNTSSERVICE_DIR/users/fakeuser"
printf '[User]\nIcon=/old/path\n' > "$uf"
sh src/set-gdm-avatar fakeuser >/dev/null 2>&1
expect_ok "backup file exists" test -f "$uf.bak"
is "backup keeps old content" "$(cat "$uf.bak")" "[User]
Icon=/old/path"

# 6: .face absent -> exit 1
fresh_as 4
home="$tmp/home4"; mkdir -p "$home"   # no .face
export GETENT_HOME="$home"
expect_exit "missing .face -> exit 1" 1 sh src/set-gdm-avatar fakeuser

# 7: nonexistent user -> exit 1
fresh_as 5
expect_exit "nonexistent user -> exit 1" 1 sh src/set-gdm-avatar ghost