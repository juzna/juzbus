import Foundation
import JuzbusProtocols

/// Async wrapper for directory service client
final class DirectoryService: @unchecked Sendable {
    private var connection: NSXPCConnection?
    private var directory: DirectoryProtocol?

    /// Connects to the directory service
    func connect() async throws {
        // Create connection to the directory service
        let connection = NSXPCConnection(
            machServiceName: JuzbusConstants.machServiceName,
            options: []
        )
        connection.remoteObjectInterface = NSXPCInterface(with: DirectoryProtocol.self)

        connection.invalidationHandler = { [weak self] in
            self?.disconnect()
        }

        connection.interruptionHandler = { [weak self] in
            self?.disconnect()
        }

        connection.resume()

        // Get the directory proxy
        guard let proxy = connection.remoteObjectProxy as? DirectoryProtocol else {
            connection.invalidate()
            throw JuzbusError.connectionFailed("Failed to create directory proxy")
        }

        self.connection = connection
        self.directory = proxy
    }

    /// Lists all registered instance names
    func listInstances() async throws -> [String] {
        guard let directory = directory else {
            throw JuzbusError.connectionFailed("Not connected to directory")
        }

        return try await withCheckedThrowingContinuation { continuation in
            directory.listInstances { instances in
                continuation.resume(returning: instances)
            }
        }
    }

    /// Retrieves the XPC endpoint for a specific instance
    func endpoint(for instanceName: String) async throws -> NSXPCListenerEndpoint {
        guard let directory = directory else {
            throw JuzbusError.connectionFailed("Not connected to directory")
        }

        return try await withCheckedThrowingContinuation { continuation in
            directory.endpoint(for: instanceName) { endpoint in
                if let endpoint = endpoint {
                    continuation.resume(returning: endpoint)
                } else {
                    continuation.resume(throwing: JuzbusError.instanceNotFound(instanceName))
                }
            }
        }
    }

    /// Disconnects from the directory service
    func disconnect() {
        connection?.invalidate()
        connection = nil
        directory = nil
    }

    deinit {
        disconnect()
    }
}
