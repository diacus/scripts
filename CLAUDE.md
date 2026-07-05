# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when
working with code in this repository.

## Overview
Personal collection of standalone CLI scripts (POSIX `sh` and
Perl). No build system, test suite, or linter — each script is
self-contained.

## Layout convention
- `src/<name>` — the script itself (kept executable, mode 0755).
- `doc/<name>.org` — the companion man page, authored in org mode. This is
  the *source* of the man page.
- `man/man1/<name>.1` — the generated groff man page, produced from
  `doc/<name>.org` at install time by `tools/build-man.el` (Emacs `ox-man`).
  These files are build artifacts: `man/man1/` is gitignored, so do not edit
  or commit them — edit the `doc/*.org` source instead.
- `install.sh` — glob-based installer (not an explicit list): it first
  regenerates `man/man1/*.1` from `doc/*.org`, then iterates everything in
  `src/` and `man/man1/`, so adding a script + org doc is enough to get it
  installed. Backup files (`*~`) are skipped via `--ignore-backups`.

## Installing
```sh
sh install.sh
```
First regenerates the man pages from `doc/*.org` via Emacs (requires
`emacs` on `PATH`; if absent, man pages are skipped with a warning and
scripts still install). Then installs scripts to `/opt/bin` (must be on
`PATH`) and man pages to `/opt/man` (see `manpath(5)`). Prefix is hardcoded
to `/opt` in `install.sh`.

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
3. Re-run `sh install.sh` to deploy. There is nothing else to build or
   test.
