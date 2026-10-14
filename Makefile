.PHONY: lint build test check sim scenarios parity linux run app install uninstall release e2e e2e-drag day typecheck-mac typecheck-mac-selftest rehearse trace trace-check replay fuzz attack clean

# Files that would compile on Linux but not on macOS, and Mac shell scripts that would change a person's Mac,
# found without a Mac.
lint:
	@python3 scripts/lint-imports.py
	@python3 scripts/lint-share-space.py --self-test && python3 scripts/lint-share-space.py
	@python3 scripts/lint-mac-shell.py --self-test > /dev/null || python3 scripts/lint-mac-shell.py --self-test
	@python3 scripts/lint-mac-shell.py
	@python3 scripts/lint-paste-safe.py --self-test && python3 scripts/lint-paste-safe.py
	@python3 scripts/mac-shell/jolts.py --self-test > /dev/null || python3 scripts/mac-shell/jolts.py --self-test

build:
	swift build

test:
	swift test

# Check the imports, build, test, run the simulator through a dock/zoom/back script, run the scenarios, check that
# the tools that report all this can also report a failure, and test the release tooling.
check: lint build test
	@./scripts/sim-smoke.sh
	@./scripts/privacy-smoke.sh
	@./scripts/scenarios.sh
	@python3 scripts/test-tooling.py
	@./scripts/release-tools-test.sh

# make sim ARGS='"open Safari" "dock 101 left"'
sim: build
	@.build/debug/arbor-sim $(ARGS)

# The documenter's user journeys in collab/scenarios (VERBOSE=1 for full output).
scenarios: build
	@./scripts/scenarios.sh

# Score Arbor against TrellisWM and regenerate docs/FEATURES.md (see collab/README.md).
parity: build
	@python3 scripts/parity.py

# check, scenarios and parity for the headless stack in the Linux image CI uses. Needs Docker.
linux:
	@./scripts/linux.sh

# Runs the debug binary from this terminal, which then needs Accessibility
# permission (System Settings → Privacy & Security → Accessibility).
# Not for loops and agents, which have no terminal on standard input: it arranges every window of whoever owns the Mac, on
# their settings and their arrangement. ARBOR_UNATTENDED=1 if the owner asked for it.
run: build
	@[ -t 0 ] || [ "$$ARBOR_UNATTENDED" = 1 ] || { echo "make run: nobody is at a terminal here, and this Arbor would arrange every window on this Mac. Nothing was started (ARBOR_UNATTENDED=1 if its owner asked for it)"; exit 77; }
	.build/debug/Arbor

# build/Arbor.app for this Mac, stamped with the version and signed: with $$ARBOR_SIGN_IDENTITY, else with the
# certificate scripts/make-signing-identity.sh makes, else ad hoc. See docs/INSTALL.md.
app:
	@./scripts/bundle.sh

# Quits a running Arbor, replaces ~/Applications/Arbor.app, links arborctl onto the PATH and starts the new build.
# make install PREFIX=/Applications BINDIR=/usr/local/bin LAUNCH=0
install: app
	@PREFIX="$(PREFIX)" BINDIR="$(BINDIR)" LAUNCH="$(LAUNCH)" ./scripts/install.sh

# Removes the login item, the app and the link. Settings and state stay.
uninstall:
	@PREFIX="$(PREFIX)" BINDIR="$(BINDIR)" ./scripts/install.sh --uninstall

# A universal build/Arbor.app as a zip and a disk image, with checksums, notes and the Homebrew cask, in build/.
# Notarized when $$ARBOR_NOTARY_PROFILE is set.
release:
	@./scripts/release.sh

# Records a trace from the running Arbor into collab/evidence/traces/<NAME>.jsonl (docs/TRACES.md).
#   make trace NAME=safari-drag          until you press return
#   make trace NAME=safari-drag FOR=15   for 15 seconds
trace: build
	@./scripts/trace.sh "$(NAME)" $(FOR)

# Lists every piece of free text in a trace, to read before committing it.
trace-check:
	@python3 scripts/trace-check.py "$(FILE)"

# Replays a trace against the real controller and tells the story, with drawings of the layout.
#   make replay FILE=collab/evidence/traces/drag-to-edge.jsonl [STRICT=1] [VERBOSE=1]
replay: build
	@.build/debug/arbor-sim replay "$(FILE)" $(if $(STRICT),--strict) $(if $(VERBOSE),--verbose)

# Starts Arbor on damaged state.json and settings.json files, a fresh process each (docs/TESTING.md, "Launch fuzzing").
# A sample, a few minutes; `scripts/fuzz-launch.py all` for everything, about an hour.
fuzz: build
	@python3 scripts/fuzz-launch.py all --limit 300

# Real windows, real Accessibility. Needs permission for this terminal.
# Saves the output to collab/evidence/e2e-latest.txt when windows were driven.
e2e: build
	@./scripts/e2e.sh

# Real drags with the real pointer, which it takes over for about half a minute. Same permission.
e2e-drag:
	@./scripts/mac-shell/e2e-drag.sh

# The rehearsal of the acceptance pass, from anywhere: an ordinary day with real apps on one of GitHub's Macs, macOS at its default
# settings, every frame of every window written down, and a table of what broke which rule (docs/TESTING.md, "An ordinary day").
# Runs what GitHub has of the current branch. CONTROL=1 plays the same day without Arbor.
day:
	@./scripts/mac-shell/run.sh scripts/mac-shell/day$(if $(CONTROL),-control).sh

# On Linux: type-checks all the macOS-only code against stand-ins for Apple's frameworks (scripts/typecheck-mac/README.md).
# Not proof, but fifteen seconds instead of a macOS job. REF=origin/some-branch checks that commit's Sources instead.
typecheck-mac:
	@./scripts/typecheck-mac/check.sh $(REF)

# Holds typecheck-mac to the files in scripts/typecheck-mac/probes: what is wrong there must be reported, what is right must not.
typecheck-mac-selftest:
	@./scripts/typecheck-mac/selftest.py

# Mac shell scripts against stand-ins built on the fakes: proves the scripts, not Arbor. On Linux only.
# make rehearse SCRIPTS="scripts/mac-shell/shots-demo.sh" (docs/TESTING.md, "Rehearse it first, for nothing")
rehearse:
	@./scripts/mac-shell/rehearse.sh $(SCRIPTS)

# Hostile and broken clients against the control socket of arbor-sim --serve, for half a minute (scripts/socket-attack.py).
attack: build
	@python3 scripts/socket-attack.py

clean:
	rm -rf .build build
