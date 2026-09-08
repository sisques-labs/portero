import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var portMonitor: PortMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar agent: no Dock icon, no Cmd-Tab entry.
        NSApp.setActivationPolicy(.accessory)

        let monitor = PortMonitor()
        let controller = StatusBarController(portMonitor: monitor)

        portMonitor = monitor
        statusBarController = controller

        monitor.start()
    }
}
