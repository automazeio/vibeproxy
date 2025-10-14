cask "vibeproxy" do
  version "1.0.5"
  sha256 "1797879f2dabed8a3a0549c1184e3eaf7a02046f61ddf68feb5559c1abc4270e"

  url "https://github.com/automazeio/vibeproxy/releases/download/v#{version}/VibeProxy.zip"
  name "VibeProxy"
  desc "Native macOS menu bar app for AI subscription proxying"
  homepage "https://github.com/automazeio/vibeproxy"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "VibeProxy.app"

  zap trash: [
    "~/.cli-proxy-api",
    "~/Library/Preferences/io.automaze.vibeproxy.plist",
  ]
end
