#!/bin/sh
set -e
umask 022

# Build a .deb package containing the scripts in src/ and the man pages
# generated from doc/*.org.  The man pages are built with tools/build-man.el
# (Emacs + ox-man); the section of each page is discovered from its
# MAN_CLASS_OPTIONS :section-id keyword.
#
# Output: scripts_<ver>_<arch>.deb in the repo root.

pkg=scripts
ver=1.0
arch=all
prefix=/usr/local
buildroot=build/deb
out=${pkg}_${ver}_${arch}.deb

allscripts=`ls --ignore-backups src`

# Regenerate groff man pages from the org sources in doc/ using ox-man
# (Emacs). The man/man<sect>/*.<sect> files are build artifacts, gitignored;
# the section <sect> is discovered from each doc's MAN_CLASS_OPTIONS
# :section-id keyword by tools/build-man.el.  Emacs is a hard build-time
# requirement: the .deb must ship the man pages, so we abort if it is absent.
build_manpages () {
    rm -rf man
    if ! command -v emacs >/dev/null 2>&1
    then
	echo "error: emacs not found; cannot rebuild man pages from doc/*.org" >&2
	exit 1
    fi
    emacs --batch -Q -l tools/build-man.el
}

assemble_tree () {
    rm -rf "$buildroot"
    mkdir -p "$buildroot/DEBIAN"
    mkdir -p "$buildroot$prefix/bin"

    for script in $allscripts
    do
	install -Dm755 "src/$script" "$buildroot$prefix/bin/$script"
    done

    for section in `seq 1 8`
    do
	test -d "man/man$section" || continue
	mkdir -p "$buildroot$prefix/share/man/man$section"
	for page in `ls --ignore-backups "man/man$section"`
        do
	    install -Dm644 "man/man$section/$page" \
		"$buildroot$prefix/share/man/man$section/$page"
        done
    done
}

write_control () {
    cat > "$buildroot/DEBIAN/control" <<EOF
Package: $pkg
Version: $ver
Section: utils
Priority: optional
Architecture: $arch
Maintainer: Diacus Magnuz <diacus.magnuz@gmail.com>
Depends: perl, less, sudo, xinput, network-manager, byzanz, xdotool, x11-utils, libnotify-bin, xdg-utils, ffmpeg, slurp, wf-recorder, libglib2.0-bin
Description: Personal collection of standalone CLI scripts
 POSIX sh and Perl utility scripts with companion man pages built
 from org-mode sources.
EOF
}

build_manpages
assemble_tree
write_control
dpkg-deb --build --root-owner-group "$buildroot" "$out"

rm -rf build man
echo "built $out"
