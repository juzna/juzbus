import Foundation
import JuzbusProtocols
import os.log

/// Delegate for the directory service XPC listener.
/// Handles incoming connections and configures them with the appropriate protocol interface.
class DirectoryServiceDelegate: NSObject, NSXPCListenerDelegate {
    private let logger = OSLog.juzbus(category: JuzbusLogCategory.directory)
    private let directoryService: DirectoryService

    init(directoryService: DirectoryService) {
        self.directoryService = directoryService
        super.init()
    }

    /// Called when a new XPC connection is received.
    /// Configures the connection with the DirectoryProtocol interface and accepts it.
    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        os_log(.info, log: logger, "Accepting new XPC connection from PID %d", newConnection.processIdentifier)

        // Configure the connection with the DirectoryProtocol interface
        let interface = NSXPCInterface(with: DirectoryProtocol.self)
        newConnection.exportedInterface = interface
        newConnection.exportedObject = directoryService

        // Set up handlers for connection lifecycle
        newConnection.invalidationHandler = { [weak self] in
            guard let self = self else { return }
            os_log(.debug, log: self.logger, "Connection invalidated from PID %d", newConnection.processIdentifier)
        }

        newConnection.interruptionHandler = { [weak self] in
            guard let self = self else { return }
            os_log(.debug, log: self.logger, "Connection interrupted from PID %d", newConnection.processIdentifier)
        }

        // Start the connection
        newConnection.resume()

        return true
    }
}
