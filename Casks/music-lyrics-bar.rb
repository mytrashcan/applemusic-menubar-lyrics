cask "music-lyrics-bar" do
  version "0.0.5"
  # Draft: one local ad-hoc ZIP. The public v0.0.5 release has only the arm64 asset.
  # Pin the published universal ZIP after signing, stapling and final packaging.
  sha256 "3f31dbe614e3fe519f3229154d682856888c64af52e34f64fde030ab8ef91b97"

  url "https://github.com/mytrashcan/applemusic-menubar-lyrics/releases/download/v#{version}/MusicLyricsBar-v#{version}-macOS-universal.zip"
  name "Music Lyrics Bar"
  desc "Follow Apple Music lyrics in the menu bar"
  homepage "https://github.com/mytrashcan/applemusic-menubar-lyrics"

  depends_on macos: :ventura

  app "Music Lyrics Bar.app"
end
