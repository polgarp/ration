import ServiceManagement

/// Starting Ration when the user logs in.
///
/// A menu bar meter that vanishes on every reboot is a meter nobody trusts, but
/// registering without asking is the kind of thing that makes people delete an
/// app, so this is a toggle and defaults to off.
enum LoginItem {

    enum State {
        case off
        case on
        /// Registered, but macOS wants the user to confirm it in System
        /// Settings — usually because login items for this app were denied
        /// before. Not a failure, and not something an error alert should claim.
        case needsApproval
    }

    /// `notFound` is reported for an app launchd has no record of, which is the
    /// ordinary state before the first registration — and registering from
    /// there succeeds. It is not a reason to refuse the attempt, so the only
    /// arbiter of whether this can work is `register()` itself.
    static var state: State {
        switch SMAppService.mainApp.status {
        case .enabled:          return .on
        case .requiresApproval: return .needsApproval
        default:                return .off
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
