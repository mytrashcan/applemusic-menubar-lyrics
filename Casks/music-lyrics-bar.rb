cask "music-lyrics-bar" do
  version "0.0.6"
  sha256 "27c33f63a1f7a88416f3e146cae57f1ab6bccc563f2d2ddac6d57ff1af20117c"

  url "https://github.com/mytrashcan/applemusic-menubar-lyrics/releases/download/v#{version}/MusicLyricsBar-v#{version}-macOS-universal.zip"
  name "Music Lyrics Bar"
  desc "Follow Apple Music lyrics in the menu bar"
  homepage "https://github.com/mytrashcan/applemusic-menubar-lyrics"

  depends_on macos: :ventura

  app "Music Lyrics Bar.app"

  caveats <<~EOS
    This build is ad-hoc signed and not notarized, so the first launch needs
    System Settings → Privacy & Security → Open Anyway.
  EOS
end
