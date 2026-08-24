import Foundation

func runInstallerTests(_ t: Harness) {
    let tap = "bash ~/.claude/claude-usage-tap.sh"

    func settings(_ name: String) -> Data {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/settings/\(name).json")
        return (try? Data(contentsOf: url)) ?? Data()
    }
    func command(_ data: Data) -> String? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sl = o["statusLine"] as? [String: Any] else { return nil }
        return sl["command"] as? String
    }
    func refresh(_ data: Data) -> Int? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sl = o["statusLine"] as? [String: Any] else { return nil }
        return sl["refreshInterval"] as? Int
    }

    t.describe("Installer — reading what is already there")
    t.expect("no status line at all", Installer.inspect(settings("none"), tap: tap), .notConfigured)
    t.expect("somebody else's status line",
             Installer.inspect(settings("custom"), tap: tap),
             .unwrapped("bash ~/.claude/statusline.sh"))
    t.expect("already ours", Installer.inspect(settings("wrapped"), tap: tap), .wrapped)
    // Refusing to touch a file we cannot parse is the whole safety story: a bug
    // here breaks a stranger's Claude Code on a machine we will never see.
    t.expect("unparseable settings", Installer.inspect(settings("malformed"), tap: tap), .unreadable)

    t.describe("Installer — wrapping preserves the existing command exactly")
    let installed = try? Installer.install(into: settings("custom"), tap: tap)
    t.expect("the original command survives verbatim, behind the tap",
             command(installed ?? Data()) ?? "", "\(tap) bash ~/.claude/statusline.sh")
    t.expect("refreshInterval is set so idle sessions still report",
             refresh(installed ?? Data()) ?? -1, 10)
    t.expect("unrelated settings are untouched",
             (try? JSONSerialization.jsonObject(with: installed ?? Data()) as? [String: Any])?["model"] as? String ?? "",
             "opus")

    t.describe("Installer — installing twice does not double-wrap")
    let twice = try? Installer.install(into: installed ?? Data(), tap: tap)
    t.expect("command is unchanged", command(twice ?? Data()) ?? "",
             "\(tap) bash ~/.claude/statusline.sh")

    t.describe("Installer — a faster refresh the user chose is never slowed down")
    let fast = try? Installer.install(into: settings("fast-refresh"), tap: tap)
    t.expect("keeps their 2s", refresh(fast ?? Data()) ?? -1, 2)

    t.describe("Installer — with no status line of their own")
    let bare = try? Installer.install(into: settings("none"), tap: tap)
    t.expect("the tap runs alone", command(bare ?? Data()) ?? "", tap)

    t.describe("Installer — uninstall restores exactly what was there")
    let reverted = try? Installer.uninstall(from: installed ?? Data(), tap: tap)
    t.expect("the original command is back",
             command(reverted ?? Data()) ?? "", "bash ~/.claude/statusline.sh")
    t.expect("and the state reads as unconfigured again",
             Installer.inspect(reverted ?? Data(), tap: tap), .unwrapped("bash ~/.claude/statusline.sh"))

    t.describe("Installer — uninstalling what we added alone removes the block")
    let bareReverted = try? Installer.uninstall(from: bare ?? Data(), tap: tap)
    t.expect("no orphan status line is left behind",
             Installer.inspect(bareReverted ?? Data(), tap: tap), .notConfigured)

    t.describe("Installer — refuses to write what it cannot read")
    var threw = false
    do { _ = try Installer.install(into: settings("malformed"), tap: tap) } catch { threw = true }
    t.expect("install throws rather than guessing", threw, true)
    threw = false
    do { _ = try Installer.uninstall(from: settings("malformed"), tap: tap) } catch { threw = true }
    t.expect("uninstall throws too", threw, true)

    t.describe("Installer — a status line shaped in a way we do not understand")
    // Rule 1 one level down. Reading `"statusLine": "script.sh"` as "no status
    // line" would have silently replaced it, which is losing their command by
    // another route.
    let oddShape = Data(#"{"statusLine": "bash ~/.claude/statusline.sh"}"#.utf8)
    t.expect("a non-object status line is unreadable, not unconfigured",
             Installer.inspect(oddShape, tap: tap), .unreadable)
    threw = false
    do { _ = try Installer.install(into: oddShape, tap: tap) } catch { threw = true }
    t.expect("and install refuses to overwrite it", threw, true)
    let oddCommand = Data(#"{"statusLine": {"type": "command", "command": ["a", "b"]}}"#.utf8)
    t.expect("nor is a non-string command something we may replace",
             Installer.inspect(oddCommand, tap: tap), .unreadable)
    // An explicit null is a genuine absence, not a shape we failed to read.
    t.expect("an explicitly null status line is simply unconfigured",
             Installer.inspect(Data(#"{"statusLine": null}"#.utf8), tap: tap), .notConfigured)

    t.describe("Installer — the preview names the actual change")
    let preview = Installer.preview(for: .unwrapped("bash ~/.claude/statusline.sh"), tap: tap)
    t.expect("shows the command before", preview.contains("bash ~/.claude/statusline.sh"), true)
    t.expect("shows the command after", preview.contains("\(tap) bash ~/.claude/statusline.sh"), true)
}
