import Foundation
import os.log

/// Example application that demonstrates instance registration and command handling.
class ExampleApp {
    private let logger = OSLog(subsystem: "cz.juzna.juzbus", category: "example")
    private let instanceName: String
    private let startTime: Date

    init(instanceName: String) {
        self.instanceName = instanceName
        self.startTime = Date()
        os_log(.info, log: logger, "ExampleApp initialized with name: %{public}@", instanceName)
    }

    /// Handles a command and returns a response.
    func handleCommand(_ command: String) -> String {
        os_log(.debug, log: logger, "Handling command: %{public}@", command)

        let parts = command.split(separator: " ", maxSplits: 1)
        let cmd = String(parts.first ?? "")
        let args = parts.count > 1 ? String(parts[1]) : ""

        switch cmd {
        case "ping":
            return "pong"

        case "get-name":
            return instanceName

        case "get-uptime":
            let uptime = Int(Date().timeIntervalSince(startTime))
            return "\(uptime) seconds"

        case "echo":
            return args.isEmpty ? "" : args

        default:
            return "Unknown command: \(cmd). Available: ping, get-name, get-uptime, echo <text>"
        }
    }
}
