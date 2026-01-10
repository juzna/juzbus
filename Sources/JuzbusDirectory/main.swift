import Foundation
import JuzbusProtocols
import os.log

let logger = OSLog.juzbus(category: JuzbusLogCategory.directory)

os_log(.info, log: logger, "juzbus-directory starting...")

// Create the directory service and its delegate
let directoryService = DirectoryService()
let delegate = DirectoryServiceDelegate(directoryService: directoryService)

// Create the XPC listener with the mach service name
let listener = NSXPCListener(machServiceName: JuzbusConstants.machServiceName)
listener.delegate = delegate

os_log(.info, log: logger, "Starting XPC listener on mach service: %{public}@", JuzbusConstants.machServiceName)

// Set up signal handlers for graceful shutdown
signal(SIGINT) { _ in
    os_log(.info, log: logger, "Received SIGINT, shutting down...")
    exit(0)
}

signal(SIGTERM) { _ in
    os_log(.info, log: logger, "Received SIGTERM, shutting down...")
    exit(0)
}

// Start listening for connections
listener.resume()

os_log(.info, log: logger, "Directory service ready, entering run loop...")

// Run the main run loop
RunLoop.main.run()
