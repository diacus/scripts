#!/bin/sh

allscripts=`ls --ignore-backups src`
prefix=/opt

install_scripts () {
    for script in $allscripts
    do
	script_name=`basename $script`
	install -Dm755 src/$script $prefix/bin/$script_name
    done
}

# Regenerate groff man pages from the org sources in doc/ using ox-man
# (Emacs). The man/man<sect>/*.<sect> files are build artifacts, gitignored;
# the section <sect> is discovered from each doc's MAN_CLASS_OPTIONS
# :section-id keyword by tools/build-man.el.
build_manpages () {
    rm -rf man
    if ! command -v emacs >/dev/null 2>&1
    then
	echo "warning: emacs not found; man pages not rebuilt from doc/*.org" >&2
	return 0
    fi
    emacs --batch -l tools/build-man.el
}

install_manpages () {
    for section in `seq 1 8`
    do
	test -d man/man$section || continue
	for page in `ls --ignore-backups man/man$section`
        do
	    install -Dm644 man/man$section/$page $prefix/man/man$section/$page
        done

    done
}

build_manpages
install_scripts
install_manpages