import Darwin

enum ProcessKiller {
    static func terminate(pid: Int32) {
        kill(pid, SIGTERM)
    }

    static func forceKill(pid: Int32) {
        kill(pid, SIGKILL)
    }
}
