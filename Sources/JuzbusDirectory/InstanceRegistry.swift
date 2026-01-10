import Foundation
import JuzbusProtocols
import os.log

/// Thread-safe registry for tracking registered instances and their XPC endpoints.
actor InstanceRegistry {
    private let logger = OSLog.juzbus(category: JuzbusLogCategory.directory)

    /// Map of instance names to their XPC endpoints
    private var instances: [String: NSXPCListenerEndpoint] = [:]

    /// Registers a new instance with the given name and endpoint.
    /// - Parameters:
    ///   - name: The unique instance name
    ///   - endpoint: The XPC endpoint for the instance
    /// - Returns: true if registration succeeded, false if name already exists or is invalid
    func add(name: String, endpoint: NSXPCListenerEndpoint) -> Bool {
        // Validate instance name
        guard name.isValidInstanceName else {
            os_log(.error, log: logger, "Invalid instance name: %{public}@", name)
            return false
        }

        // Check for duplicate
        if instances[name] != nil {
            os_log(.error, log: logger, "Instance name already registered: %{public}@", name)
            return false
        }

        // Register the instance
        instances[name] = endpoint
        os_log(.info, log: logger, "Registered instance: %{public}@", name)
        return true
    }

    /// Removes an instance from the registry.
    /// - Parameter name: The instance name to remove
    func remove(name: String) {
        if instances.removeValue(forKey: name) != nil {
            os_log(.info, log: logger, "Unregistered instance: %{public}@", name)
        }
    }

    /// Retrieves the endpoint for a specific instance.
    /// - Parameter name: The instance name to look up
    /// - Returns: The endpoint if found, nil otherwise
    func endpoint(for name: String) -> NSXPCListenerEndpoint? {
        return instances[name]
    }

    /// Returns a list of all registered instance names.
    /// - Returns: Array of instance names, sorted alphabetically
    func listInstances() -> [String] {
        return Array(instances.keys).sorted()
    }

    /// Returns the number of registered instances.
    var count: Int {
        return instances.count
    }
}
