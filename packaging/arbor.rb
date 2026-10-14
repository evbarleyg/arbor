# The Homebrew cask for Arbor. This file is a template: `make release` fills in @VERSION@ and @SHA256@ and
# writes the result to build/arbor.rb. It goes live when the repository is public, because Homebrew downloads the
# disk image from the release page without credentials. Then it belongs in a tap, a repository named
# evbarleyg/homebrew-tap, as Casks/arbor.rb, and installs with `brew install --cask evbarleyg/tap/arbor`.
cask "arbor" do
  version "@VERSION@"
  sha256 "@SHA256@"

  url "https://github.com/evbarleyg/arbor/releases/download/v#{version}/Arbor-#{version}.dmg"
  name "Arbor"
  desc "Dock windows side by side, then zoom between them"
  homepage "https://github.com/evbarleyg/arbor"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "Arbor.app"
  binary "#{appdir}/Arbor.app/Contents/Helpers/arborctl"

  # What Arbor switched off under Desktop & Dock for its owner (`fix-setup`) goes back as it was. With nothing to put back it says so.
  uninstall_preflight do
    system_command "#{appdir}/Arbor.app/Contents/MacOS/Arbor", args: ["--fix-setup", "undo"], must_succeed: false
  end

  uninstall quit:       "com.evbarleyg.arbor",
            login_item: "Arbor"

  zap trash: "~/Library/Application Support/Arbor"

  caveats <<~EOS
    Arbor needs Accessibility permission to move other apps' windows:
      System Settings → Privacy & Security → Accessibility

    Until Arbor is notarized, macOS blocks its first launch. Allow it under
      System Settings → Privacy & Security → Open Anyway
    and, because each release has a signature of its own, remove Arbor's entry
    under Accessibility after an upgrade and let it ask again.
  EOS
end
