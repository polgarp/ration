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
        case unavailable
    }

    static var state: State {
        switch SMAppService.mainApp.status {
        case .enabled:           return .on
        case .requiresApproval:  return .needsApproval
        case .notRegistered:     return .off
        case .notFound:          return .unavailable
        @unknown default:        return .unavailable
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
