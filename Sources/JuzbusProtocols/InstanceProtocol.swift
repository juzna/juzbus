import Foundation

/// Protocol for individual application instances.
/// Each running instance exposes this protocol over an anonymous XPC listener,
/// allowing clients to send commands and receive responses.
@objc public protocol InstanceProtocol {
    /// Executes a command on this instance.
    /// - Parameters:
    ///   - command: The command string to execute
    ///   - reply: Callback with the command response
    func runCommand(
        _ command: String,
        reply: @escaping (String) -> Void
    )
}
