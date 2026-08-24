# Homebrew Cask template for BunnyBar.
#
# The historical filename says "formula", but BunnyBar ships as a macOS .app
# bundle and must be distributed as a Cask. Replace the placeholders before
# adding this stanza to a tap's Casks/bunnybar.rb.
cask "bunnybar" do
  version "<VERSION>"
  sha256 "<SHA256_HERE>"

  url "https://github.com/hiroyannnn/BunnyBar/releases/download/v#{version}/BunnyBar-#{version}.zip"
  name "BunnyBar"
  desc "CPU-aware rabbit companion for the macOS menu bar"
  homepage "https://github.com/hiroyannnn/BunnyBar"

  app "BunnyBar.app"

  uninstall quit: "com.hiroyannnn.BunnyBar"

  zap trash: "~/Library/Preferences/com.hiroyannnn.BunnyBar.plist"
end
