#!/bin/sh

allscripts=`ls --ignore-backups src`
allman=`ls --ignore-backups man/man1`
prefix=/opt

install_scripts () {
    for script in $allscripts
    do
	script_name=`basename $script`
	install -Dm755 src/$script $prefix/bin/$script_name
    done
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

install_scripts
install_manpages
