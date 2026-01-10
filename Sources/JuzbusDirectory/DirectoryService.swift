import Foundation
import JuzbusProtocols
import os.log

/// The main directory service that implements the DirectoryProtocol.
/// Manages the instance registry and handles registration, lookup, and discovery.
class DirectoryService: NSObject, DirectoryProtocol, @unchecked Sendable {
    private let logger = OSLog.juzbus(category: JuzbusLogCategory.directory)
    private let registry = InstanceRegistry()

    /// Lists all currently registered instance names.
    func listInstances(reply: @escaping ([String]) -> Void) {
        Task {
            let instances = await self.registry.listInstances()
            os_log(.debug, log: self.logger, "listInstances called, returning %d instances", instances.count)
            reply(instances)
        }
    }

    /// Retrieves the XPC endpoint for a specific instance.
    func endpoint(for name: String, reply: @escaping (NSXPCListenerEndpoint?) -> Void) {
        Task {
            let endpoint = await self.registry.endpoint(for: name)
            if endpoint != nil {
                os_log(.debug, log: self.logger, "Found endpoint for instance: %{public}@", name)
            } else {
                os_log(.info, log: self.logger, "No endpoint found for instance: %{public}@", name)
            }
            reply(endpoint)
        }
    }

    /// Registers a new instance with the directory.
    /// Sets up an invalidation handler to automatically clean up if the instance disconnects.
    func register(name: String, endpoint: NSXPCListenerEndpoint, reply: @escaping (Bool) -> Void) {
        Task { [weak self] in
            guard let self = self else { return }
            // Attempt to register
            let success = await self.registry.add(name: name, endpoint: endpoint)

            if success {
                // Set up a test connection to monitor the endpoint's validity
                let testConnection = NSXPCConnection(listenerEndpoint: endpoint)
                testConnection.remoteObjectInterface = NSXPCInterface(with: InstanceProtocol.self)

                // Set up invalidation handler to clean up when instance disconnects
                testConnection.invalidationHandler = { [weak self] in
                    guard let self = self else { return }
                    os_log(.info, log: self.logger, "Instance endpoint invalidated: %{public}@", name)
                    Task { [weak self] in
                        guard let self = self else { return }
                        await self.registry.remove(name: name)
                    }
                }

                testConnection.resume()
                os_log(.info, log: self.logger, "Successfully registered instance: %{public}@", name)
            }

            reply(success)
        }
    }

    /// Unregisters an instance from the directory.
    func unregister(name: String) {
        Task { [weak self] in
            guard let self = self else { return }
            await self.registry.remove(name: name)
            os_log(.info, log: self.logger, "Unregister called for instance: %{public}@", name)
        }
    }

    /// Returns the current number of registered instances (for debugging).
    func instanceCount() async -> Int {
        return await registry.count
    }
}
