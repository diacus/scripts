# POSIX sh TAP helpers. Source this from a .t file, then:
#   plan N
#   is "desc" "got" "expected"
#   contains "desc" "haystack" "needle"
#   matches "desc" "haystack" "glob"
#   expect_exit "desc" expected_code cmd...
#   expect_ok "desc" cmd...
#   skip "desc" "reason"

_tap_n=0

plan () {
    echo "1..$1"
}

_tap_pass () {
    _tap_n=$((_tap_n + 1))
    echo "ok $_tap_n - $1"
}

_tap_fail () {
    _tap_n=$((_tap_n + 1))
    echo "not ok $_tap_n - $1"
    shift
    [ $# -gt 0 ] && printf '# %s\n' "$*" >&2
}

# is DESC GOT EXPECTED
is () {
    if [ "$2" = "$3" ]; then
        _tap_pass "$1"
    else
        _tap_fail "$1" "expected [$3] got [$2]"
    fi
}

# contains DESC HAYSTACK NEEDLE
contains () {
    case "$2" in
        *"$3"*) _tap_pass "$1" ;;
        *) _tap_fail "$1" "expected [$2] to contain [$3]" ;;
    esac
}

# matches DESC HAYSTACK GLOB
matches () {
    case "$2" in
        $3) _tap_pass "$1" ;;
        *) _tap_fail "$1" "expected [$2] to match glob [$3]" ;;
    esac
}

# expect_exit DESC EXPECTED_CODE cmd...
expect_exit () {
    _te_d="$1"; _te_e="$2"; shift 2
    "$@" >/dev/null 2>&1
    _te_r=$?
    if [ "$_te_r" = "$_te_e" ]; then
        _tap_pass "$_te_d"
    else
        _tap_fail "$_te_d" "expected exit $_te_e got $_te_r"
    fi
}

# expect_ok DESC cmd...   (expects exit 0)
expect_ok () {
    _to_d="$1"; shift
    if "$@" >/dev/null 2>&1; then
        _tap_pass "$_to_d"
    else
        _tap_fail "$_to_d" "command failed (exit $?)"
    fi
}

# expect_fail DESC cmd...   (expects non-zero exit)
expect_fail () {
    _tf_d="$1"; shift
    "$@" >/dev/null 2>&1
    _tf_r=$?
    if [ "$_tf_r" != 0 ]; then
        _tap_pass "$_tf_d"
    else
        _tap_fail "$_tf_d" "expected non-zero exit got 0"
    fi
}

# skip DESC REASON
skip () {
    _tap_n=$((_tap_n + 1))
    echo "ok $_tap_n - $1 # SKIP $2"
}