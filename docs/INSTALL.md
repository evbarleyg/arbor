# Installing Arbor

Arbor needs macOS 14 or later. Building it needs Swift 6.2 or later, which comes with Xcode 26. The Command Line Tools are
enough, without Xcode itself: `xcode-select --install` fetches them. `swift --version` says what you have.
Nothing else: only `make check` and the tools in `scripts/` want a `python3`, 3.9 or later.

What stands behind that: every change is built and tested on GitHub's Macs with the Swift of their newest Xcode (6.3 today), and
compiled on Linux with 6.2 and with the newest release; before anything reaches `main`, a Mac compiles all of it with Xcode 26.0 and
with the newest Swift as well. An older Swift says so in one line (see Troubleshooting).

## From source, in three commands

```bash
git clone https://github.com/evbarleyg/arbor && cd arbor
./scripts/make-signing-identity.sh
make install
```

The second is wanted once per Mac; what it is for is explained below. The blocks on this page hold commands and nothing
else, so that they can be pasted whole: at its prompt macOS's own shell, zsh, does not take `#` for a comment.

`make install`

1. builds `build/Arbor.app` for this Mac, stamps it with the version and signs it;
2. asks a running Arbor to quit, which puts every window back in view, and waits until it has (only one Arbor runs
   at a time);
3. replaces `~/Applications/Arbor.app`;
4. links `arborctl` into `~/.local/bin` if that is on your `PATH`, else into `/usr/local/bin` if you may write there,
   else into `~/.local/bin` all the same, and then tells you the line that adds it to your `PATH`;
5. starts the new build and prints its status;
6. if the build is signed ad hoc, says so last and aloud, with what that costs: macOS will ask for the permission again.

It is for a person at a terminal. From a script, a loop or an agent (standard input is no terminal) `make install`, `make uninstall`,
`make run` and `scripts/make-signing-identity.sh` decline with exit code 77 and touch nothing, because they quit the Arbor you are using, replace it with no
copy kept, let a build arrange all your windows, or change your login keychain. `ARBOR_UNATTENDED=1` says that you asked for it.

| Variable | Meaning |
|---|---|
| `PREFIX=/Applications` | Install there instead of `~/Applications` (an administrator may) |
| `BINDIR=/usr/local/bin` | Link `arborctl` there |
| `LAUNCH=0` | Do not start Arbor afterwards |
| `ARBOR_CONFIGURATION=debug` | Compile without the optimizer, as `swift build` and the tests do (see Troubleshooting) |
| `ARBOR_SIGN_IDENTITY="Developer ID Application: …"` | Sign with that certificate; `-` forces an ad-hoc signature |

On first launch Arbor asks for **Accessibility** permission (System Settings → Privacy & Security → Accessibility),
which it needs to move other apps' windows. It starts arranging the moment you switch it on; there is no need
to restart it. macOS's own window tiling is on as a Mac comes, and with it on the left, right and top edges of the screen are macOS's: Arbor
stands aside there. Turn it off (System Settings → Desktop & Dock → Windows) and every edge docks: `docs/GUIDE.md`, section 2.

## The signing identity, and why

macOS does not give a permission to a file or a name. It gives it to a **code signature**, and what it writes down is
the signature's *designated requirement*: the test a program must pass to count as the same app next time.

- A build without a certificate is signed **ad hoc**, and its requirement is the hash of that very build:

  ```
  designated => cdhash H"4d1c0f8e…"
  ```

  The next build has another hash, so to macOS it is a stranger: **System Settings still shows Arbor switched on, and Arbor is told
  it has no permission.** A tester saw that, and so did a hosted Mac (macOS 26.6.2, one run): the switch read on and the entry stayed
  as it was, allowed, for the first build's hash, while the second build waited.
- A build signed with a certificate has a requirement that names the app and the certificate:

  ```
  designated => identifier "com.evbarleyg.arbor" and certificate leaf = H"9b7e52a1…"
  ```

  Every build signed with that certificate passes it. **The permission is given once and stays**: on a Mac with macOS 26.6.2 the
  next build, different code, ran without being granted anything. **One ad-hoc build in between costs it**: seconds after a build
  without the certificate had started in the same place, having asked for nothing, the entry read denied, and the next build with
  the certificate had to be given the permission again. (One run. What the switch shows for such an entry, nobody has looked at yet.)

A Developer ID from Apple is such a certificate, and costs a yearly fee. For your own Mac, one you make yourself does
the same job. `scripts/make-signing-identity.sh` makes it:

- a self-signed certificate named **Arbor Local Signing**, good for code signing and nothing else, valid for ten
  years, with a new private key that cannot be exported, in your login keychain;
- nothing is trusted, nothing is installed system-wide, nothing leaves the Mac, and no administrator rights are needed.
  `codesign` signs with a certificate nobody trusts, and the permission database only asks whether the next build
  is signed with the same one;
- it asks for **no password**, takes none, and changes nothing about any key but its own. **macOS asks, once, in a dialog of its own**:
  "codesign wants to access key “Arbor Local Signing” in your keychain. To allow this, enter the “login” keychain password." Type
  the password you log in with there, and choose **Always Allow**. Allow works this once, and macOS asks again at every build,
  twice; after Deny nothing is signed. Why it asks: in the login keychain an imported key has a list of who may use it unasked, and
  `codesign` is not on it until you say so;
- it ends by signing something with the new key, and goes by that. If the signature cannot be made, or you press ⌃C, it says why as far as
  anybody knows and takes the certificate and the key out of the keychain again: a certificate that is there and of no use would make
  every build fail or wait for a dialog. macOS's dialog it cannot take away: one that nobody answered stays on the screen, asking
  about a key that is gone. Close it with Deny;
- running it again changes nothing, but tries a signature and says so if that fails; `--remove` deletes the certificate and the key.

From then on `make app` and `make install` find the certificate and sign with it, and say so. The order is:
`ARBOR_SIGN_IDENTITY` if set, else "Arbor Local Signing" if a keychain has it, else ad hoc. The build knows which it was:
`arborctl doctor` has a line **Signature**, and Check Setup says under Accessibility when macOS will ask again after the next update.

**The first build signed this way needs the permission once more**, because its signature is new. If an older build of
Arbor is listed under Accessibility, clear that entry, between the old Arbor's quitting and the new one's start. The
first line quits the Arbor that is running, replaces it and starts nothing:

```bash
make install LAUNCH=0
tccutil reset Accessibility com.evbarleyg.arbor
open ~/Applications/Arbor.app
```

Not before: an Arbor that is running needs its permission to bring windows back into view when it quits. Not after: Arbor
asks for its entry when it starts, so an entry cleared later does not come back until the next start.

What you are agreeing to: once `codesign` may use the key without asking, any program running as you could sign itself
as "com.evbarleyg.arbor" and inherit the permissions you gave Arbor. That is the price of not being asked, and the same
as on any developer's Mac with a signing certificate. Without the identity nothing is lost but convenience.

## Updating

```bash
git pull && make install
```

With the signing identity that is all. With ad-hoc signatures, see "Arbor says it has no permission" below after
every update.

`arborctl --version` prints the installed version, and says so when the Arbor that is running is another build;
`arborctl version` and `arborctl status` print the running one. `0.9.0 (build 214, 47a2ba9)` is the version (the
`VERSION` file), the number of commits and the commit.

**Arbor never updates itself.** *Check for Updates…* in the menu, or `arborctl check-for-updates`, asks GitHub for the
latest release, compares versions, and offers to open the release page if there is a newer one. It downloads and
installs nothing. Nothing is asked unless you ask: with `"automaticUpdateChecks": true` in `settings.json` Arbor also asks
a minute after it starts and once a week from then on. Such a check never opens a window; when it finds a newer
release the menu item reads *Update Available…*, and `arborctl version` says which. The request is one unauthenticated
GET that carries Arbor's version and nothing about you. While no release is published GitHub has none to name, and Arbor
says "no update information".

## Launch at login

*Open at Login* in the settings window (Settings… in the menu, General), or:

```bash
arborctl launch-at-login on
```

Or `off`; without a word it answers on or off.

macOS keeps the list (System Settings → General → Login Items & Extensions, under "Open at Login"), and remembers the
app bundle, so this works from `~/Applications` as from `/Applications`, and a new build installed over the old one keeps
its place. It needs the app bundle: `make run` cannot open at login. If you move Arbor.app, switch it off and on again.
If you switch Arbor off in System Settings, only you can switch it back on there; the menu item takes you to the pane.

## Uninstalling

```bash
make uninstall
```

(with the same `PREFIX` and `BINDIR` as `make install`, if you gave any) quits Arbor (every window comes back into
view), removes the login item, the app and the `arborctl` link. If you had Arbor switch off macOS's own tiling
(`fix-setup`, "Switch Off macOS Tiling" under Help → Check Setup…), those settings went back as they were when it quit, and the note of your choice goes too; `brew uninstall` does the same. Dragging the app to the Trash does none of
this; quit Arbor first, which gives the settings back.

**It looks before it removes.** An Arbor that may not move windows (its switch under Accessibility is off, or belongs
to a build with another signature) or that hangs puts nothing back when it goes, and the app is the only thing that
could fetch what is out of view. So once Arbor has quit, the window server is asked whether any window is still all
but off every display (`scripts/out-of-view.swift`: no permission needed, no title read). If so nothing is removed,
exit code 75, and it says what to do: open Arbor again, switch it on, `arborctl float-all`, look, uninstall.
`ARBOR_LEAVE_WINDOWS=1` removes it all the same, for windows that another tool keeps there. `make install` looks too,
and only says what it saw: the build that comes brings them back when it starts.

It leaves, and lists:

| What | Where | To remove it |
|---|---|---|
| Settings, your arrangement, the log | `~/Library/Application Support/Arbor` | `rm -r` it |
| Arbor's entry under Accessibility | System Settings | `tccutil reset Accessibility com.evbarleyg.arbor` |
| The signing certificate | login keychain | `scripts/make-signing-identity.sh --remove` |

## A downloaded build

Releases carry a disk image and a zip for Apple silicon and Intel. Until the project has an Apple Developer ID they are
signed ad hoc and not notarized, which costs two detours that building from source does not have:

1. **The first launch is blocked.** macOS marks downloads as quarantined and refuses one that Apple has not checked:
   "Apple could not verify "Arbor" is free of malware". Click **Done**, open System Settings → Privacy & Security, scroll
   down to "Arbor was blocked to protect your Mac" and click **Open Anyway**. Right-click → Open no longer gets past
   this on current macOS. Or take the mark off in Terminal:

   ```bash
   xattr -dr com.apple.quarantine /Applications/Arbor.app
   ```

2. **Every update needs the permission again**, because every release has a signature of its own: see the next section.

To check a download: `shasum -a 256 -c Arbor-<version>-checksums.txt`.

**Homebrew.** `packaging/arbor.rb` is a cask; `make release` fills in the version and the checksum. It goes live when
the repository is public, because Homebrew downloads without credentials: then
`brew install --cask evbarleyg/tap/arbor`.

## Troubleshooting

**Arbor says it has no permission, and System Settings shows it switched on.** The entry belongs to a build with
another signature: an ad-hoc build that has been replaced, or a build from before (or after) you made the signing
identity. Select Arbor in the list, remove it with the − button, and let Arbor ask again; or

```bash
tccutil reset Accessibility com.evbarleyg.arbor
```

and switch it on when it asks. `arborctl status` says `waiting for Accessibility permission` until then, and `running`
a second after. To see what macOS compares: `codesign -d -r- ~/Applications/Arbor.app`.

**`make install` ends with "THIS BUILD IS SIGNED AD HOC".** No keychain has the signing identity, so every build is a new app to macOS
and has to be given the permission again. `./scripts/make-signing-identity.sh`, then `make install`, and it is asked once more and
never again. `security find-identity -p codesigning` lists "Arbor Local Signing" if it is there.

**The script asked for the keychain's password and said it was wrong.** That was its fault, not yours, and it asks no longer:
`git pull`. It looked for its key by a name that macOS 15 and 26 no longer give, and took every failure for a wrong password. If it
left a certificate behind, running it again says whether `codesign` can sign with it, and what to do if not.

**"It had no answer in 60 seconds".** The script ran with nobody at a terminal (`ARBOR_UNATTENDED=1`, a job), and nobody answered macOS's
dialog. Close the dialog with Deny, run the script from a terminal, and answer with Always Allow. `ARBOR_KEYCHAIN_PASSWORD`, which used to
spare scripts the dialog, is no longer looked at: a login password does not belong in a script's arguments or environment.

**`errSecInternalComponent` from the script's trial.** The dialog was answered Deny or closed, or the keychain is locked, as it is over
ssh (`security unlock-keychain`).

**"no identity found" or "The specified item could not be found in the keychain" from codesign, with `ARBOR_SIGN_KEYCHAIN` or
`--keychain`.** codesign finds an identity only in a keychain on the search list, whatever `--keychain` says. `security list-keychains -d user` shows the list; with `-s` and every
keychain that is to be on it, it sets it.

**macOS asks whether codesign may use the key, at every build.** Someone chose Allow instead of Always Allow. Choose
Always Allow, or run `scripts/make-signing-identity.sh --remove` and make the identity again.

**`errSecInternalComponent` from codesign.** The keychain is locked, as it is over ssh: `security unlock-keychain`, or
build with `ARBOR_SIGN_IDENTITY=-`.

**"Arbor Local Signing: ambiguous".** Two certificates have the name. `scripts/make-signing-identity.sh --remove` deletes
both; then make one again.

**`arborctl: command not found`.** The folder it was linked into is not on your `PATH`; `make install` prints the line
that adds it. It is always at `~/Applications/Arbor.app/Contents/Helpers/arborctl`.

**`package 'arbor' is using Swift tools version 6.2.0 but the installed version is …`.** Your Swift is older than Arbor can be built
with. Update Xcode or the Command Line Tools to 26 or later (Software Update offers them; `xcode-select --install` where there are
none). Where macOS is too old for those, a downloaded build is the way: see above.

**`make install` stops with compiler errors.** `swift build` tells whether the sources compile at all. If they do, and only the
optimized build fails, `ARBOR_CONFIGURATION=debug make install` installs the build that every test runs against; it is slower
in ways nobody is likely to notice in a window manager. Please report the errors.

**Arbor does not start, or stops.** `~/Library/Application Support/Arbor/arbor.log` says why (menu → Help → Show Log).

## Making a release

1. Set the version in `VERSION`, the one place it is written down, and see that the top section of `CHANGELOG.md` says
   what changed: it becomes the release notes.
2. Run the **Release** workflow **with "rehearsal" unticked** (Actions → Release → Run workflow, or
   `gh workflow run release.yml -f rehearsal=false`), on a branch or on the tag `v<version>`. A suffix makes a pre-release
   of the version in `VERSION`, which update checks do not offer: `v0.9.0-rc.1`. The workflow starts only by hand: pushing
   a tag marks a commit and does nothing else.
3. It runs `make check` and `make release` on a Mac and leaves a **draft** on the releases page with the disk image, the
   zip, the checksums, the cask and the notes. Read it, then publish it; publishing creates the tag if there is none.

With "rehearsal" ticked, as it is to begin with, it does all of that except the last step: nothing is sent to the releases
page, and there is nothing to send with. The one job whose token can write does not start, and no other reads a secret or a
signing identity; `scripts/lint-workflows.py` holds the file to that.

`make release` does the same build locally, into `build/`: universal binaries, `Arbor-<version>.zip` and `.dmg`,
`Arbor-<version>-checksums.txt`, `Arbor-<version>-notes.md` and `arbor.rb`.

**With a Developer ID** (untested: the project has none yet):

```bash
xcrun notarytool store-credentials arbor --apple-id <you> --team-id <team> --password <app-specific password>
ARBOR_SIGN_IDENTITY="Developer ID Application: <name> (<team>)" ARBOR_NOTARY_PROFILE=arbor make release
```

signs with the hardened runtime and a secure timestamp, has Apple notarize the app and the disk image, staples
the tickets, and checks the result with `spctl --assess`. The notes then leave out the detours above.
