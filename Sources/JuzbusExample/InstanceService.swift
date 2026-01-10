import Foundation
import JuzbusProtocols
import os.log

/// XPC service that implements the InstanceProtocol and manages registration with the directory.
class InstanceService: NSObject, InstanceProtocol {
    private let logger = OSLog(subsystem: "cz.juzna.juzbus", category: "example")
    private let app: ExampleApp
    private let instanceName: String
    private let listener: NSXPCListener
    private var directoryConnection: NSXPCConnection?

    init(instanceName: String, app: ExampleApp) {
        self.instanceName = instanceName
        self.app = app
        self.listener = NSXPCListener.anonymous()
        super.init()

        // Set up the listener
        self.listener.delegate = self
    }

    /// Starts the XPC listener and registers with the directory service.
    func start() -> Bool {
        // Start the anonymous listener
        listener.resume()
        os_log(.info, log: logger, "Started anonymous XPC listener")

        // Connect to the directory service
        let connection = NSXPCConnection(
            machServiceName: JuzbusConstants.machServiceName,
            options: []
        )
        connection.remoteObjectInterface = NSXPCInterface(with: DirectoryProtocol.self)

        connection.invalidationHandler = { [weak self] in
            guard let self = self else { return }
            os_log(.error, log: self.logger, "Directory connection invalidated")
        }

        connection.interruptionHandler = { [weak self] in
            guard let self = self else { return }
            os_log(.default, log: self.logger, "Directory connection interrupted")
        }

        connection.resume()
        self.directoryConnection = connection

        // Register with the directory
        let directory = connection.remoteObjectProxy as? DirectoryProtocol

        let semaphore = DispatchSemaphore(value: 0)
        var registrationSuccess = false

        directory?.register(
            name: instanceName,
            endpoint: listener.endpoint
        ) { [weak self] success in
            guard let self = self else { return }
            registrationSuccess = success
            if success {
                os_log(.info, log: self.logger, "Successfully registered with directory as: %{public}@", self.instanceName)
            } else {
                os_log(.error, log: self.logger, "Failed to register with directory")
            }
            semaphore.signal()
        }

        // Wait for registration to complete
        _ = semaphore.wait(timeout: .now() + JuzbusConstants.defaultTimeout)

        return registrationSuccess
    }

    /// Unregisters from the directory service.
    func stop() {
        os_log(.info, log: logger, "Unregistering from directory...")

        if let directory = directoryConnection?.remoteObjectProxy as? DirectoryProtocol {
            directory.unregister(name: instanceName)
        }

        directoryConnection?.invalidate()
        listener.invalidate()

        os_log(.info, log: logger, "Stopped")
    }

    // MARK: - InstanceProtocol

    func runCommand(_ command: String, reply: @escaping (String) -> Void) {
        os_log(.debug, log: logger, "Received command: %{public}@", command)
        let response = app.handleCommand(command)
        reply(response)
    }
}

// MARK: - NSXPCListenerDelegate

extension InstanceService: NSXPCListenerDelegate {
    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        os_log(.info, log: logger, "Accepting XPC connection from PID %d", newConnection.processIdentifier)

        // Configure the connection
        let interface = NSXPCInterface(with: InstanceProtocol.self)
        newConnection.exportedInterface = interface
        newConnection.exportedObject = self

        newConnection.invalidationHandler = { [weak self] in
            guard let self = self else { return }
            os_log(.debug, log: self.logger, "Client connection invalidated")
        }

        newConnection.interruptionHandler = { [weak self] in
            guard let self = self else { return }
            os_log(.debug, log: self.logger, "Client connection interrupted")
        }

        newConnection.resume()
        return true
    }
}
