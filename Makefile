# Makefile for the scripts collection.
#
#   make        build the .deb package (default)
#   make deb    build the .deb package (scripts_1.0_all.deb)
#   make man    regenerate groff man pages from doc/*.org for review
#   make test   run the test suite (no install, root, or display required)
#               pass through flags with TESTARGS, e.g. `make test TESTARGS=-v`
#   make clean  remove build artifacts (build/, man/, *.deb)
#
# man/manN/* and build/ are gitignored build artifacts; doc/*.org are the
# man-page sources.

EMACS  := emacs
DEB    := scripts_1.0_all.deb
SRCS   := $(wildcard src/*)
DOCS   := $(wildcard doc/*.org)

.PHONY: all deb man test clean

all: deb

# Build the .deb package: regenerates man pages, assembles the tree under
# build/deb, writes DEBIAN/control, and runs dpkg-deb --build. Delegates to
# build-deb.sh, which cleans up build/ and man/ when done.
deb: build-deb.sh $(SRCS) $(DOCS) tools/build-man.el
	sh build-deb.sh

# Regenerate groff man pages from doc/*.org via Emacs (ox-man), leaving
# them under man/manN/ for manual review. Emacs is a hard requirement.
man: $(DOCS) tools/build-man.el
	@command -v $(EMACS) >/dev/null 2>&1 || { \
		echo "error: $(EMACS) not found; cannot build man pages from doc/*.org" >&2; \
		exit 1; }
	rm -rf man
	$(EMACS) --batch -Q -l tools/build-man.el
	@echo "man pages regenerated under man/"

# Run the TAP test suite straight from src/ (no install needed).
# Extra flags (e.g. -v for verbose TAP) can be passed via TESTARGS:
#   make test TESTARGS=-v
test: $(SRCS)
	sh test/run.sh $(TESTARGS)

# Remove every build artifact.
clean:
	rm -rf build man scripts_*.deb