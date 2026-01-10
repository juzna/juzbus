import Foundation
import JuzbusProtocols

/// Client for connecting to the directory service and retrieving instance information.
class DirectoryClient {
    private let connection: NSXPCConnection
    private let directory: DirectoryProtocol

    init() throws {
        // Create connection to the directory service
        connection = NSXPCConnection(
            machServiceName: JuzbusConstants.machServiceName,
            options: []
        )
        connection.remoteObjectInterface = NSXPCInterface(with: DirectoryProtocol.self)

        connection.invalidationHandler = {
            // Connection invalidated
        }

        connection.interruptionHandler = {
            // Connection interrupted
        }

        connection.resume()

        // Get the directory proxy
        guard let proxy = connection.remoteObjectProxy as? DirectoryProtocol else {
            connection.invalidate()
            throw JuzbusError.connectionFailed("Failed to create directory proxy")
        }

        self.directory = proxy
    }

    /// Lists all registered instance names.
    func listInstances() -> Result<[String], Error> {
        var result: Result<[String], Error> = .failure(JuzbusError.timeout)
        let semaphore = DispatchSemaphore(value: 0)

        directory.listInstances { instances in
            result = .success(instances)
            semaphore.signal()
        }

        let timeout = DispatchTime.now() + JuzbusConstants.defaultTimeout
        if semaphore.wait(timeout: timeout) == .timedOut {
            return .failure(JuzbusError.timeout)
        }

        return result
    }

    /// Retrieves the XPC endpoint for a specific instance.
    func endpoint(for instanceName: String) -> Result<NSXPCListenerEndpoint, Error> {
        var result: Result<NSXPCListenerEndpoint, Error> = .failure(JuzbusError.timeout)
        let semaphore = DispatchSemaphore(value: 0)

        directory.endpoint(for: instanceName) { endpoint in
            if let endpoint = endpoint {
                result = .success(endpoint)
            } else {
                result = .failure(JuzbusError.instanceNotFound(instanceName))
            }
            semaphore.signal()
        }

        let timeout = DispatchTime.now() + JuzbusConstants.defaultTimeout
        if semaphore.wait(timeout: timeout) == .timedOut {
            return .failure(JuzbusError.timeout)
        }

        return result
    }

    /// Closes the connection to the directory service.
    func disconnect() {
        connection.invalidate()
    }
}
