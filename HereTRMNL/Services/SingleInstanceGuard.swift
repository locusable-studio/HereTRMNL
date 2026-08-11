import AppKit

enum SingleInstanceGuard {
    /// If another running copy exists, activate it and terminate this process.
    static func ensureSingleInstance() {
        guard !AppRuntime.isRunningTests else { return }

        let bundleID = Bundle.main.bundleIdentifier
        let others = NSWorkspace.shared.runningApplications.filter { app in
            guard app.bundleIdentifier == bundleID else { return false }
            return app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        }

        guard let existing = others.first else { return }
        existing.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        NSApp.terminate(nil)
        exit(0)
    }
}
