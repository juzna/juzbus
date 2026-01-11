# juzbus

**juzbus** is a macOS XPC-based directory service that enables multiple running instances of an application to register with human-readable names and be discovered and controlled by CLI clients or other applications.

## Features

- **Multiple Instances**: Support for multiple running instances of an application
- **Human-Readable Names**: Each instance registers with a unique, meaningful name
- **Discovery**: Clients can list all registered instances
- **Command & Control**: Send commands to specific instances via XPC
- **Native macOS IPC**: Uses XPC and launchd for reliable, secure communication
- **Per-User**: Runs in user session, no elevated privileges required
- **On-Demand**: Directory service starts automatically when needed

## Architecture

```
┌─────────────────┐
│  CLI / Client   │
└────────┬────────┘
         │ XPC (mach service)
         ▼
┌─────────────────┐
│   Directory     │ ◄── Maintains registry
│   LaunchAgent   │     of instances
└────────┬────────┘
         │ hands out endpoints
         ▼
┌─────────────────┐
│ App Instance    │ ◄── Anonymous XPC
│ (per instance)  │     listener per app
└─────────────────┘
```

### Components

1. **Directory Service** (`juzbus-directory`): A LaunchAgent that maintains an in-memory registry mapping instance names to XPC endpoints
2. **CLI Client** (`juzbus`): Command-line tool for discovering instances and sending commands
3. **Example App** (`juzbus-example`): Demonstrates how applications register and handle commands

## Installation

### Prerequisites

- macOS 13.0 or later
- Xcode Command Line Tools or Xcode (for Swift compiler)

### Build and Install

```bash
# Clone or navigate to the project directory
cd juzbus

# Run the installation script
./Scripts/install.sh
```

This will:
1. Build release binaries
2. Copy them to `/usr/local/bin/`
3. Install and load the LaunchAgent

### Development Installation (Symlink Mode)

For active development, use the symlink installation to avoid reinstalling after each rebuild:

```bash
# Install with symlinks instead of copies
./Scripts/install-symlink.sh
```

This creates symlinks to `.build/release/`, so after running `swift build -c release`, changes are immediately available without reinstallation.

### Verify Installation

```bash
# Check if binaries are installed
which juzbus
which juzbus-example

# The directory service will start on-demand when first accessed
```

## Usage

### Starting an Example Instance

```bash
# Start an instance with a name
juzbus-example my-instance

# Start multiple instances with different names
juzbus-example window-1 &
juzbus-example window-2 &
juzbus-example project-foo &
```

### Listing Instances

```bash
# List all registered instances
juzbus list
```

Output:
```
Registered instances (3):
  project-foo
  window-1
  window-2
```

### Sending Commands to Instances

```bash
# Send a command to a specific instance
juzbus exec window-1 ping
# Output: pong

# Get the instance name
juzbus exec window-1 get-name
# Output: window-1

# Get instance uptime
juzbus exec window-1 get-uptime
# Output: 42 seconds

# Echo a message
juzbus exec window-1 "echo Hello, World!"
# Output: Hello, World!
```

### CLI Commands

```bash
juzbus list                           # List all instances
juzbus exec <instance> <command>      # Send command to instance
juzbus --help                         # Show help
```

## Integrating with Your Application

### 1. Add JuzbusProtocols as a Dependency

In your `Package.swift`:

```swift
dependencies: [
    .package(path: "../juzbus")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "JuzbusProtocols", package: "juzbus")
        ]
    )
]
```

### 2. Create an Instance Service

```swift
import Foundation
import JuzbusProtocols

class YourAppService: NSObject, InstanceProtocol {
    private let listener = NSXPCListener.anonymous()
    private let instanceName: String

    init(instanceName: String) {
        self.instanceName = instanceName
        super.init()
        listener.delegate = self
    }

    func start() {
        listener.resume()

        // Connect to directory
        let connection = NSXPCConnection(
            machServiceName: JuzbusConstants.machServiceName
        )
        connection.remoteObjectInterface = NSXPCInterface(with: DirectoryProtocol.self)
        connection.resume()

        // Register
        let directory = connection.remoteObjectProxy as? DirectoryProtocol
        directory?.register(name: instanceName, endpoint: listener.endpoint) { success in
            print("Registered: \(success)")
        }
    }

    // Implement InstanceProtocol
    func runCommand(_ command: String, reply: @escaping (String) -> Void) {
        // Handle your application-specific commands
        let response = handleCommand(command)
        reply(response)
    }
}

extension YourAppService: NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener,
                 shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        let interface = NSXPCInterface(with: InstanceProtocol.self)
        newConnection.exportedInterface = interface
        newConnection.exportedObject = self
        newConnection.resume()
        return true
    }
}
```

### 3. Register on Startup

```swift
let service = YourAppService(instanceName: "my-app-\(UUID())")
service.start()
```

## Protocol Reference

### DirectoryProtocol

```swift
protocol DirectoryProtocol {
    func listInstances(reply: @escaping ([String]) -> Void)
    func endpoint(for name: String, reply: @escaping (NSXPCListenerEndpoint?) -> Void)
    func register(name: String, endpoint: NSXPCListenerEndpoint, reply: @escaping (Bool) -> Void)
    func unregister(name: String)
}
```

### InstanceProtocol

```swift
protocol InstanceProtocol {
    func runCommand(_ command: String, reply: @escaping (String) -> Void)
}
```

## Instance Naming Rules

- Must contain only alphanumeric characters, hyphens, and underscores
- Must be between 1 and 64 characters long
- Must be unique per user
- Duplicate names are rejected by the directory service

Valid examples: `window-1`, `project-foo`, `instance_123`

## Debugging

### View Directory Service Logs

```bash
# Tail the log file
tail -f /tmp/juzbus-directory.log

# Or use the system log
log stream --predicate 'subsystem == "cz.juzna.juzbus"'
```

### Check LaunchAgent Status

```bash
# List loaded LaunchAgents
launchctl list | grep juzbus

# Reload the LaunchAgent
launchctl unload ~/Library/LaunchAgents/cz.juzna.juzbus.plist
launchctl load ~/Library/LaunchAgents/cz.juzna.juzbus.plist
```

### Common Issues

**"Failed to connect to directory service"**
- The directory service will start automatically on first XPC connection
- If it's not starting, check: `launchctl list | grep juzbus`
- Try manually loading: `launchctl load ~/Library/LaunchAgents/cz.juzna.juzbus.plist`

**"Instance not found"**
- Use `juzbus list` to see registered instances
- Make sure the instance is still running

**"Invalid instance name"**
- Check naming rules above
- Avoid special characters except hyphens and underscores

## Testing

Run the automated test workflow:

```bash
./Scripts/test-workflow.sh
```

This will:
1. Start multiple example instances
2. List them
3. Send various commands
4. Verify cleanup

## Uninstallation

```bash
./Scripts/uninstall.sh
```

This will:
1. Unload the LaunchAgent
2. Remove all binaries
3. Remove the LaunchAgent plist

## Technical Details

- **Mach Service Name**: `cz.juzna.juzbus`
- **LaunchAgent**: `~/Library/LaunchAgents/cz.juzna.juzbus.plist`
- **Binaries**: `/usr/local/bin/juzbus*`
- **Logs**: `/tmp/juzbus-directory.log`
- **Platform**: macOS 13.0+
- **Language**: Swift 6.0
- **Build System**: Swift Package Manager

## Security

- The directory service runs in the user's session (no elevated privileges)
- XPC connections are secured by launchd (per-user mach services)
- No cross-user access
- No network exposure
- Sandbox-compatible

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
