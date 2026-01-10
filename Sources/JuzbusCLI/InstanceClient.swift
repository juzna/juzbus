import Foundation
import JuzbusProtocols

/// Client for connecting to a specific instance and sending commands.
class InstanceClient {
    private let connection: NSXPCConnection
    private let instance: InstanceProtocol

    init(endpoint: NSXPCListenerEndpoint) throws {
        // Create connection to the instance via its endpoint
        connection = NSXPCConnection(listenerEndpoint: endpoint)
        connection.remoteObjectInterface = NSXPCInterface(with: InstanceProtocol.self)

        connection.invalidationHandler = {
            // Connection invalidated
        }

        connection.interruptionHandler = {
            // Connection interrupted
        }

        connection.resume()

        // Get the instance proxy
        guard let proxy = connection.remoteObjectProxy as? InstanceProtocol else {
            connection.invalidate()
            throw JuzbusError.connectionFailed("Failed to create instance proxy")
        }

        self.instance = proxy
    }

    /// Sends a command to the instance and returns the response.
    func runCommand(_ command: String) -> Result<String, Error> {
        var result: Result<String, Error> = .failure(JuzbusError.timeout)
        let semaphore = DispatchSemaphore(value: 0)

        instance.runCommand(command) { response in
            result = .success(response)
            semaphore.signal()
        }

        let timeout = DispatchTime.now() + JuzbusConstants.defaultTimeout
        if semaphore.wait(timeout: timeout) == .timedOut {
            return .failure(JuzbusError.timeout)
        }

        return result
    }

    /// Closes the connection to the instance.
    func disconnect() {
        connection.invalidate()
    }
}
