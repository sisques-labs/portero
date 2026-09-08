import AppKit

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let portMonitor: PortMonitor
    private let filterField = FilterFieldView()

    private var entries: [PortEntry] = []
    private var filterText: String = ""

    init(portMonitor: PortMonitor) {
        self.portMonitor = portMonitor
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "door.left.hand.open", accessibilityDescription: "Portero")
        }

        filterField.onTextChange = { [weak self] text in
            self?.filterText = text
            self?.rebuildMenu()
        }

        portMonitor.onUpdate = { [weak self] entries in
            self?.entries = entries
            self?.rebuildMenu()
        }

        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let filterItem = NSMenuItem()
        filterItem.view = filterField
        menu.addItem(filterItem)
        menu.addItem(.separator())

        let filtered = filteredEntries()

        if filtered.isEmpty {
            let emptyItem = NSMenuItem(title: "No listening ports", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for entry in filtered {
                menu.addItem(menuItem(for: entry))
            }
        }

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Portero", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func filteredEntries() -> [PortEntry] {
        guard !filterText.isEmpty else { return entries }
        return entries.filter {
            String($0.port).contains(filterText) ||
            $0.processName.localizedCaseInsensitiveContains(filterText)
        }
    }

    private func menuItem(for entry: PortEntry) -> NSMenuItem {
        let item = NSMenuItem(
            title: ":\(entry.port) · \(entry.processName) · PID \(entry.pid)",
            action: nil,
            keyEquivalent: ""
        )

        let submenu = NSMenu()

        let terminateItem = NSMenuItem(
            title: "Terminate (SIGTERM)",
            action: #selector(terminate(_:)),
            keyEquivalent: ""
        )
        terminateItem.target = self
        terminateItem.representedObject = entry.pid
        submenu.addItem(terminateItem)

        let forceKillItem = NSMenuItem(
            title: "Force Kill (SIGKILL)",
            action: #selector(forceKill(_:)),
            keyEquivalent: ""
        )
        forceKillItem.target = self
        forceKillItem.representedObject = entry.pid
        submenu.addItem(forceKillItem)

        item.submenu = submenu
        return item
    }

    @objc private func terminate(_ sender: NSMenuItem) {
        guard let pid = sender.representedObject as? Int32 else { return }
        ProcessKiller.terminate(pid: pid)
    }

    @objc private func forceKill(_ sender: NSMenuItem) {
        guard let pid = sender.representedObject as? Int32 else { return }
        ProcessKiller.forceKill(pid: pid)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
