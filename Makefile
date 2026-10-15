.PHONY: public-check hooks lint build test check sim scenarios parity linux run app install uninstall release e2e e2e-drag day typecheck-mac typecheck-mac-selftest rehearse trace trace-check replay fuzz attack clean

# Files that would compile on Linux but not on macOS, and Mac shell scripts that would change a person's Mac,
# found without a Mac. And a ledger of macOS's surprises (docs/REALITY.md) that names what is no longer there.
lint:
	@python3 scripts/test-ci-linux.py
	@python3 scripts/lint-imports.py
	@python3 scripts/lint-share-space.py --self-test && python3 scripts/lint-share-space.py
	@python3 scripts/lint-mac-shell.py --self-test > /dev/null || python3 scripts/lint-mac-shell.py --self-test
	@python3 scripts/lint-mac-shell.py
	@python3 scripts/test-fast-tests.py
	@python3 scripts/lint-paste-safe.py --self-test && python3 scripts/lint-paste-safe.py
	@for test in scripts/test-public-*.py; do python3 $$test || exit 1; done
	@python3 scripts/gh-state.py --self-test
	@python3 scripts/reality-ledger.py --self-test && python3 scripts/reality-ledger.py --check
	@python3 scripts/mac-shell/jolts.py --self-test > /dev/null || python3 scripts/mac-shell/jolts.py --self-test
	@python3 scripts/mac-shell/viable.py --self-test > /dev/null || python3 scripts/mac-shell/viable.py --self-test
	@python3 scripts/mac-shell/walk.py --self-test > /dev/null || python3 scripts/mac-shell/walk.py --self-test
	@python3 scripts/mac-shell/gate.py --self-test > /dev/null || python3 scripts/mac-shell/gate.py --self-test
	@python3 scripts/mac-shell/walk.py 4711 --acts 100 | cmp -s - scripts/mac-shell/walk-sample.sh || { echo "scripts/mac-shell/walk-sample.sh is not what walk.py 4711 --acts 100 writes"; exit 1; }

# Reads what this branch adds (lines, file names, commit messages, its own name) for what should stay private, and checks
# that its history begins where the public repository's does. Before every push (docs/PUBLIC.md).
public-check:
	@python3 scripts/public-check.py

# Has git run that check by itself before every push from this clone and its worktrees. Once per clone.
hooks:
	@./scripts/git-hooks/install.sh

build:
	swift build

# Swift Testing's own record of the run goes into a file, for scripts/parity.py and scripts/ci-step.py: what `swift test` prints
# loses lines (scripts/parity.py says how). A part of the suite: make test TEST_REPORT=… TEST_ARGS='--filter …'
TEST_REPORT ?= .build/test-report.jsonl
test:
	@rm -f $(TEST_REPORT)
	swift test --event-stream-output-path $(TEST_REPORT) --event-stream-version 0 $(TEST_ARGS)

# Check the imports, build, test, run the simulator through a dock/zoom/back script, run the scenarios, check that
# the tools that report all this can also report a failure, and test the release tooling.
check: lint build test
	@./scripts/sim-smoke.sh
	@./scripts/privacy-smoke.sh
	@./scripts/scenarios.sh
	@python3 scripts/test-tooling.py
	@./scripts/release-tools-test.sh

# On Linux: all that a change must pass before it is pushed (check, scenarios, parity, typecheck-mac, lint), each thing once and
# on every core: four minutes where those take fourteen. CHECK=1: fail if docs/FEATURES.md is out of date, as CI does.
.PHONY: gate check-fast test-fast
gate:
	@./scripts/gate.sh $(if $(CHECK),--check)
check-fast: gate

# On Linux: the tests alone, a process to a file, as many at a time as there are cores (scripts/fast-tests.py).
test-fast:
	@./scripts/fast-tests.py run

# make sim ARGS='"open Safari" "dock 101 left"'
sim: build
	@.build/debug/arbor-sim $(ARGS)

# The documenter's user journeys in collab/scenarios (VERBOSE=1 for full output).
scenarios: build
	@./scripts/scenarios.sh

# Score Arbor against TrellisWM and regenerate docs/FEATURES.md (see collab/README.md). By itself it runs the tests; after
# `check` or `test` in one call of make (`make check parity`) it reads the record they have just left, so they run once.
TESTED := $(filter check test,$(MAKECMDGOALS))
parity: $(TESTED)
	@python3 scripts/parity.py $(if $(TESTED),--report $(TEST_REPORT))

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
# Runs what GitHub has of the current branch. One of: CONTROL=1 plays the same day without Arbor; OFF=1 with macOS's own tiling switched off; STILL=1 with Reduce
# Motion on; SABOTAGE=1 commits the offences itself, to see the detectors speak. They cannot be rehearsed yet: the fake Mac knows no apptool and no sampler.
day:
	@./scripts/mac-shell/run.sh --no-preflight "the fake Mac knows no apptool, no sampler and no stock apps yet" \
	  scripts/mac-shell/day$(if $(CONTROL),-control,$(if $(OFF),-off,$(if $(STILL),-still,$(if $(SABOTAGE),-sabotage)))).sh

# On Linux: type-checks all the macOS-only code against stand-ins for Apple's frameworks (scripts/typecheck-mac/README.md).
# Not proof, but fifteen seconds instead of a macOS job. REF=origin/some-branch checks that commit's Sources instead.
typecheck-mac:
	@./scripts/typecheck-mac/check.sh $(REF)

# Holds typecheck-mac to the files in scripts/typecheck-mac/probes: what is wrong there must be reported, what is right must not.
typecheck-mac-selftest:
	@./scripts/typecheck-mac/selftest.py

.PHONY: mac-on-linux mac-on-linux-selftest
# On Linux: the real Accessibility layer (Sources/ArborKit/AX), compiled, linked and RUN against a model of a Mac that is as rude as real ones were seen
# to be (scripts/mac-on-linux/README.md). make mac-on-linux ARGS="--only tab --verbose"
mac-on-linux:
	@./scripts/mac-on-linux/build.sh $(ARGS)

# Does that net hold? Takes known cures out of a copy of the layer; the stories about them must go red.
mac-on-linux-selftest:
	@./scripts/mac-on-linux/build.sh --self-test

# Mac shell scripts against stand-ins built on the fakes: proves the scripts, not Arbor. On Linux only.
# make rehearse SCRIPTS="scripts/mac-shell/shots-demo.sh" (docs/TESTING.md, "Rehearse it first, for nothing")
rehearse:
	@./scripts/mac-shell/rehearse.sh $(SCRIPTS)

# Hostile and broken clients against the control socket of arbor-sim --serve, for half a minute (scripts/socket-attack.py).
attack: build
	@python3 scripts/socket-attack.py

clean:
	rm -rf .build build
