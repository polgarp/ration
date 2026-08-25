# Homebrew formula for Ration. Source of truth: copy this into the tap repo at
# polgarp/homebrew-tap as Casks/../Formula/ration.rb when cutting a release.
#
# A formula rather than a cask, deliberately. Casks propagate the quarantine
# flag from the download, so an unsigned app hits Gatekeeper exactly as a manual
# download would — and from 2026-09-01 Homebrew drops casks that fail Gatekeeper
# checks entirely. Building on the user's machine sidesteps both: the linker
# ad-hoc signs the binary and nothing ever quarantines it.
class Ration < Formula
  desc "Menu bar meter for Claude Code usage, with weekly pace"
  homepage "https://github.com/polgarp/ration"
  url "https://github.com/polgarp/ration/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_WITH_TARBALL_SHA256"
  license "MIT"
  head "https://github.com/polgarp/ration.git", branch: "main"

  depends_on :macos
  depends_on macos: :ventura

  def install
    # Needs only the Command Line Tools, which Homebrew itself requires.
    system "./build.sh"
    prefix.install "build/Ration.app"
    # The audience is already in a terminal: `ration --status`, `--install`,
    # `--uninstall` and `--dump` work without opening the app.
    bin.install_symlink prefix/"Ration.app/Contents/MacOS/Ration" => "ration"
  end

  def caveats
    <<~EOS
      Ration.app is installed at
        #{opt_prefix}/Ration.app

      Put it with your other apps (optional, and needed for "Open at Login"):
        ln -sfn #{opt_prefix}/Ration.app /Applications/Ration.app

      Start it:
        open #{opt_prefix}/Ration.app

      Then use the menu bar item -> "Set up Ration..." to connect it to Claude
      Code. It shows the exact change it will make to settings.json first, and
      backs the file up.

      Before uninstalling, use "Undo Setup..." so your own status line command
      is restored. Otherwise run:
        ration --uninstall
    EOS
  end

  test do
    # A throwaway config directory, so the test never touches a real ~/.claude.
    ENV["RATION_CLAUDE_DIR"] = testpath
    assert_match "not configured", shell_output("#{bin}/ration --status")
  end
end
