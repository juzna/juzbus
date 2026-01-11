import Foundation

/// Represents a command execution with its response
struct CommandExecution: Identifiable {
    let id = UUID()
    let command: String
    let response: String
    let timestamp: Date
}
