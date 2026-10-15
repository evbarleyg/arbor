# F13: Signing, notarization and updates

Status: done except what needs a Developer ID, and except the run on a Mac (`chore/F13-distribution`; see Shipped)
Depends on: F01

## Summary

`make app` produces an ad-hoc signed bundle. macOS ties Accessibility
permission to the code signature, and an ad-hoc signature changes on every
build, so each rebuild needs the permission granted again. A stable identity
fixes that; notarization lets others install it.

## Behaviour

- `make app` signs with `ARBOR_SIGN_IDENTITY` when set (Developer ID or a
  local self-signed code-signing certificate), otherwise ad-hoc, and prints which.
- `make release` builds, signs with hardened runtime, notarizes (`notarytool`,
  credentials from a keychain profile named by `ARBOR_NOTARY_PROFILE`), staples,
  and produces a zip and a DMG in `build/`.
- Optional: Sparkle updates with an appcast, and a Homebrew cask.
- Document making a local self-signed identity for developers, including the
  trust step the Mac's user must approve.

## Acceptance criteria

1. Ad-hoc path unchanged when no identity is set.
2. With an identity, `codesign --verify --deep --strict` passes and the
   designated requirement no longer contains a cdhash.
3. Release artefacts pass `spctl --assess` when notarized.

## Shipped

For users: [docs/INSTALL.md](../INSTALL.md).

- **A stable local signature.** `scripts/make-signing-identity.sh` makes, once, a self-signed code-signing certificate
  ("Arbor Local Signing") with a key that cannot be exported, in the login keychain; no trust step, no administrator
  rights, no password asked for or taken (macOS asks once, in its own dialog: Always Allow; the script signs something and goes by
  that); a run that fails or is interrupted leaves nothing; idempotent; `--remove`.
  `scripts/sign.sh` signs with `ARBOR_SIGN_IDENTITY`, else that certificate, else ad hoc, and says which and what it means
  for permissions. Any other identity gets the hardened runtime. `arborctl` has an identifier of its own and sits in
  `Contents/Helpers` (app shell review).
- **`make install` / `make uninstall`** (`scripts/install.sh`): quit the running copy and wait for it, replace
  `~/Applications/Arbor.app` (`PREFIX`), link `arborctl` onto the `PATH` (`BINDIR`), start the new build and print its status;
  uninstalling removes the login item, the app and the link and lists what it leaves.
- **Versions.** The `VERSION` file (0.9.0) is the one source; `scripts/version.sh` stamps it, the commit count and the
  commit into the bundle; `version`, `status`, `arborctl --version`, `Arbor --version`, the menu and the log show them.
  Nothing is generated at compile time; outside a bundle the version is `dev`.
- **`make release`** (`scripts/release.sh`): universal binaries, zip, disk image with a link to /Applications, checksums,
  release notes from the top of `CHANGELOG.md` with the first-launch instructions, the Homebrew cask filled in from
  `packaging/arbor.rb`. Notarization and stapling when `ARBOR_NOTARY_PROFILE` is set.
- **`.github/workflows/release.yml`**: by hand only, on a branch or a tag `v*`; `make check`, `make release` on a Mac, then a draft
  release made on Linux by `scripts/publish-release.sh` (curl and the REST API). With "rehearsal" ticked it does everything
  but the sending. Pushing a tag or a pull request starts nothing: a tag only marks a commit.
- **Updates** (T74, partial): `check-for-updates`, the menu item and the setting `automaticUpdateChecks` (off; a minute after
  starting, then weekly; it never opens a window, only the menu item's title changes). Compares with the latest GitHub
  release and offers its page. No Sparkle: no third-party code.
- **Launch at login** (T73) is a command now, `launch-at-login [on|off]`, behind a seam, with tests.

## Not shipped, not proven

- **What has run on hosted Macs (2026-10-15):** `scripts/mac-shell/check-signing.sh` whole on macOS 14.8.9, 15.7.9 and 26.6.2 (56 of 56 each):
  the identity, macOS's dialog, Always Allow, silence afterwards; on 26 in a keychain beside the login keychain, whose own password macOS
  refuses there. `check-F13.sh` to its end on 26.6.2 (80 of 84; the four were the script's own, mended since and not run again).
  `check-F13-system.sh` on 26.6.2 (27 of 28): **the next build signed with the identity runs without being granted anything**, an ad-hoc
  build does not, launch at login survives a new build and is off after `make uninstall`. The one that failed is known: `tccutil` knows no
  bundle under /tmp, so what `make install` advises for a stale entry has not been tried from a real ~/Applications.
- Criterion 3 (notarized artefacts pass `spctl --assess`) is written and cannot be tried without a Developer ID.
- The release workflow has never run; `scripts/release-tools-test.sh` tests its publishing step against a stand-in for GitHub.
- **T74 stays partial, by design** (coordinator's decision). Arbor checks (weekly, off by default) and links to the release; it does
  not download or install. A replaced ad-hoc-signed app loses its Accessibility permission, and a real updater needs a
  Developer ID and third-party code (Sparkle, an appcast), both outside the project's rules.
- The cask is not in a tap: Homebrew cannot download from a private repository.
