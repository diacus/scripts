# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when
working with code in this repository.

## Overview
Personal collection of standalone CLI scripts (POSIX `sh` and
Perl). No build system, test suite, or linter — each script is
self-contained. Distribution is via a Debian package built by
`build-deb.sh`.

## Layout convention
- `src/<name>` — the script itself (kept executable, mode 0755).
- `doc/<name>.org` — the companion man page, authored in org mode. This is
  the *source* of the man page.
- `man/man1/<name>.1` — the generated groff man page, produced from
  `doc/<name>.org` at build time by `tools/build-man.el` (Emacs `ox-man`).
  These files are build artifacts: `man/man*/` is gitignored, so do not edit
  or commit them — edit the `doc/*.org` source instead.
- `build-deb.sh` — glob-based package builder (not an explicit list): it
  regenerates `man/manN/*.N` from `doc/*.org`, then iterates everything in
  `src/` and `man/man*/`, so adding a script + org doc is enough to get it
  packaged. Backup files (`*~`) are skipped via `--ignore-backups`. The
  output `*.deb` and the `build/` staging tree are gitignored.
- `tools/build-man.el` — Emacs script that exports `doc/*.org` to
  `man/man<sect>/<name>.<sect>` (section read from `MAN_CLASS_OPTIONS
  :section-id`).

## Building the package
```sh
sh build-deb.sh
```
Regenerates the man pages from `doc/*.org` via Emacs (`emacs` must be on
`PATH`; it is a hard build-time requirement and the script aborts if
absent), assembles the package tree under `build/deb` with scripts in
`usr/local/bin` (mode 0755) and man pages in `usr/local/share/man/manN`
(mode 0644), and runs `dpkg-deb --build` to produce
`scripts_1.0_all.deb` in the repo root.

## Installing
```sh
sudo dpkg -i scripts_1.0_all.deb
```
Installs scripts to `/usr/local/bin` and man pages to
`/usr/local/share/man` (see `manpath(5)`). `apt install ./scripts_1.0_all.deb`
additionally resolves the `Depends` (perl, network-manager, byzanz, xdotool,
x11-utils, libnotify-bin, xdg-utils). Remove with `dpkg -r scripts`.

## Scripts and their runtimes
- `psh` — Perl REPL using `Term::ReadLine` + `Data::Dumper`
  (`#!/usr/bin/env perl`).
- `graba` — Perl script that records the active terminal window to a
  GIF via `byzanz-record`, `xdotool`, `xwininfo`, `notify-send`,
  `xdg-open` (`#!/usr/bin/perl -w`).
- `set-gdm-avatar` — POSIX `sh`; copies `~/.face` into AccountsService
  so the GDM login screen can show it even when `$HOME` is not
  world-traversable (0750). Uses `awk`, `install`, `getent`, `id`,
  `sudo`.
- `laptop-keyboard` — POSIX `sh`; enables/disables the laptop keyboard
  via `xinput` (float/reattach). Caches the device id in
  `/tmp/keyboard-descriptor`.

## Adding a new script
1. Write the executable script at `src/<name>` (`chmod +x`; shebang
   `#!/bin/sh` or `#!/usr/bin/env perl` as appropriate).
2. Add `doc/<name>.org`, the man-page source in org mode. Copy an existing
   `doc/*.org` as a template — they share a header convention:
   ```
   #+TITLE: <name>
   #+MAN_CLASS_OPTIONS: :section-id 1
   #+DATE: <date>
   #+MAN_VERSION: version <x.y>
   #+OPTIONS: ^:{}

   * NAME
   <name> - <one-line description>

   * SYNOPSIS
   #+BEGIN_SRC sh
   <name> [args...]
   #+END_SRC

   * DESCRIPTION / OPTIONS / DEPENDENCIES / AUTHOR
   ```
   Headlines map to `.SH` sections; description lists (`- --opt :: desc`)
   map to `.TP` items; inline `=code=` maps to `\fI...\fP`. The `#+TITLE`,
   `#+DATE` and `#+MAN_VERSION` keywords populate the generated `.TH` line
   (ox-man's own template cannot emit date/version, so `tools/build-man.el`
   rewrites the `.TH` line after export).
3. Re-run `sh build-deb.sh` and `sudo dpkg -i scripts_1.0_all.deb` to
   deploy. There is nothing else to build or test.
