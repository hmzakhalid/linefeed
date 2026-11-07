import AppKit

let application = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
application.delegate = delegate
application.setActivationPolicy(.accessory)
withExtendedLifetime(delegate) {
    application.run()
}
