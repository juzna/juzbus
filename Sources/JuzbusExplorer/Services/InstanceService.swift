import Foundation
import JuzbusProtocols

/// Async wrapper for instance client
final class InstanceService: @unchecked Sendable {
    private var connection: NSXPCConnection?
    private var instance: InstanceProtocol?

    /// Connects to an instance via its endpoint
    func connect(endpoint: NSXPCListenerEndpoint) async throws {
        // Create connection to the instance via its endpoint
        let connection = NSXPCConnection(listenerEndpoint: endpoint)
        connection.remoteObjectInterface = NSXPCInterface(with: InstanceProtocol.self)

        connection.invalidationHandler = { [weak self] in
            self?.disconnect()
        }

        connection.interruptionHandler = { [weak self] in
            self?.disconnect()
        }

        connection.resume()

        // Get the instance proxy
        guard let proxy = connection.remoteObjectProxy as? InstanceProtocol else {
            connection.invalidate()
            throw JuzbusError.connectionFailed("Failed to create instance proxy")
        }

        self.connection = connection
        self.instance = proxy
    }

    /// Sends a command to the instance and returns the response
    func runCommand(_ command: String) async throws -> String {
        guard let instance = instance else {
            throw JuzbusError.connectionFailed("Not connected to instance")
        }

        return try await withCheckedThrowingContinuation { continuation in
            instance.runCommand(command) { response in
                continuation.resume(returning: response)
            }
        }
    }

    /// Disconnects from the instance
    func disconnect() {
        connection?.invalidate()
        connection = nil
        instance = nil
    }

    deinit {
        disconnect()
    }
}
