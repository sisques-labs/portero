import Foundation

/// Error cases from process termination attempts.
enum KillError: Error, Equatable {
    case permissionDenied
    case processNotFound
    case unknownError(Int32)

    var description: String {
        switch self {
        case .permissionDenied:
            "Permission denied"
        case .processNotFound:
            "Process not found (already exited?)"
        case .unknownError(let errno):
            "Unknown error (errno: \(errno))"
        }
    }
}
