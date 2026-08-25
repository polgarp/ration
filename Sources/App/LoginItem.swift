import ServiceManagement

/// Starting Ration when the user logs in.
///
/// A menu bar meter that vanishes on every reboot is a meter nobody trusts, but
/// registering without asking is the kind of thing that makes people delete an
/// app, so this is a toggle and defaults to off.
enum LoginItem {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registration fails for a bundle macOS will not vouch for — an unsigned
    /// build run from the Downloads folder, typically. Reported rather than
    /// swallowed, so the menu never shows a tick that means nothing.
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
