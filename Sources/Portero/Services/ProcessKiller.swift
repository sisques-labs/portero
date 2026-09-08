import Darwin

enum ProcessKiller {
    static func terminate(pid: Int32) -> Result<Void, KillError> {
        let result = kill(pid, SIGTERM)
        if result == 0 {
            return .success(())
        } else {
            return .failure(mapError())
        }
    }

    static func forceKill(pid: Int32) -> Result<Void, KillError> {
        let result = kill(pid, SIGKILL)
        if result == 0 {
            return .success(())
        } else {
            return .failure(mapError())
        }
    }

    private static func mapError() -> KillError {
        switch errno {
        case EPERM:
            return .permissionDenied
        case ESRCH:
            return .processNotFound
        default:
            return .unknownError(errno)
        }
    }
}
