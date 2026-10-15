cask "arbor" do
  version "0.9.0"
  sha256 "3a4d99af8214f86b07abcdb697cd7028716cf20f3c666bc321be9c8fdad63641"

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
