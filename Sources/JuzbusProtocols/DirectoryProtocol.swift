import Foundation

/// Protocol for the directory service that maintains a registry of application instances.
/// The directory service acts as a central registry, allowing instances to register
/// and clients to discover and connect to specific instances.
@objc public protocol DirectoryProtocol {
    /// Lists all currently registered instance names.
    /// - Parameter reply: Callback with an array of instance names
    func listInstances(reply: @escaping ([String]) -> Void)

    /// Retrieves the XPC endpoint for a specific instance.
    /// - Parameters:
    ///   - name: The instance name to look up
    ///   - reply: Callback with the endpoint, or nil if instance not found
    func endpoint(
        for name: String,
        reply: @escaping (NSXPCListenerEndpoint?) -> Void
    )

    /// Registers a new instance with the directory.
    /// - Parameters:
    ///   - name: The unique name for this instance
    ///   - endpoint: The XPC endpoint for connecting to this instance
    ///   - reply: Callback with true if registration succeeded, false if name already taken
    func register(
        name: String,
        endpoint: NSXPCListenerEndpoint,
        reply: @escaping (Bool) -> Void
    )

    /// Unregisters an instance from the directory.
    /// - Parameter name: The instance name to unregister
    func unregister(name: String)
}
