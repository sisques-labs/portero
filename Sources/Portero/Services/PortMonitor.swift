import Foundation

/// Polls `lsof` for TCP sockets in LISTEN state and reports the result on the main thread.
final class PortMonitor {
    private var timer: Timer?
    private let pollInterval: TimeInterval

    var onUpdate: (([PortEntry]) -> Void)?

    init(pollInterval: TimeInterval = 2.0) {
        self.pollInterval = pollInterval
    }

    func start() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        DispatchQueue.global(qos: .utility).async {
            let entries = Self.fetchListeningPorts()
            DispatchQueue.main.async { [weak self] in
                self?.onUpdate?(entries)
            }
        }
    }

    private static func fetchListeningPorts() -> [PortEntry] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-nP", "-iTCP", "-sTCP:LISTEN"]

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe() // discard warnings (e.g. unmountable network volumes)

        do {
            try process.run()
        } catch {
            return []
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return parse(output)
    }

    /// Parses lsof's default column output:
    /// COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
    private static func parse(_ output: String) -> [PortEntry] {
        var seen = Set<String>()
        var results: [PortEntry] = []

        let lines = output.split(separator: "\n").dropFirst() // skip header row
        for line in lines {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard fields.count >= 9 else { continue }

            let processName = fields[0]
            guard let pid = Int32(fields[1]) else { continue }
            let user = fields[2]
            let name = fields[8] // e.g. "*:8080" or "127.0.0.1:8080"

            guard let portToken = name.split(separator: ":").last,
                  let port = Int(portToken) else { continue }

            let key = "\(pid)-\(port)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            results.append(
                PortEntry(port: port, proto: "TCP", pid: pid, processName: processName, user: user)
            )
        }

        return results.sorted { $0.port < $1.port }
    }
}
