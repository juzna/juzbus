import Foundation
import os.log

let logger = OSLog(subsystem: "cz.juzna.juzbus", category: "example")

// Parse command-line arguments
guard CommandLine.arguments.count >= 2 else {
    print("Usage: juzbus-example <instance-name>")
    print()
    print("Example:")
    print("  juzbus-example my-instance")
    exit(1)
}

let instanceName = CommandLine.arguments[1]

// Validate instance name
guard instanceName.isValidInstanceName else {
    print("Error: Invalid instance name '\(instanceName)'")
    print("Instance names must:")
    print("  - Contain only alphanumeric characters, hyphens, and underscores")
    print("  - Be between 1 and 64 characters long")
    exit(1)
}

os_log(.info, log: logger, "Starting juzbus-example with name: %{public}@", instanceName)

// Create the application and service
let app = ExampleApp(instanceName: instanceName)
let service = InstanceService(instanceName: instanceName, app: app)

// Set up signal handlers for graceful shutdown
var shouldExit = false

signal(SIGINT) { _ in
    shouldExit = true
}

signal(SIGTERM) { _ in
    shouldExit = true
}

// Start the service
if !service.start() {
    print("Error: Failed to register with directory service")
    print("Make sure the directory service is running:")
    print("  launchctl load ~/Library/LaunchAgents/cz.juzna.juzbus.plist")
    exit(1)
}

print("Instance '\(instanceName)' registered successfully")
print("Available commands: ping, get-name, get-uptime, echo <text>")
print("Press Ctrl+C to exit")

// Run until signaled to exit
while !shouldExit {
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
}

// Clean shutdown
os_log(.info, log: logger, "Shutting down...")
print("\nShutting down...")
service.stop()
exit(0)
