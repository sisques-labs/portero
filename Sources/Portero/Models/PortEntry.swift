import Foundation

struct PortEntry: Identifiable, Equatable {
    var id: String { "\(pid)-\(port)-\(proto)" }

    let port: Int
    let proto: String
    let pid: Int32
    let processName: String
    let user: String
}
