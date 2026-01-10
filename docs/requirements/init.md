# XPC LaunchAgent Directory Service – Requirements & Implementation Plan

## 1. Goal

Provide a **per-user command/control IPC mechanism** on macOS that:

- Supports **multiple running instances** of an application
- Allows each instance to **register under a human-readable name**
- Allows external clients (CLI or other apps) to **discover instances**
- Allows clients to **send commands to a specific instance**
- Uses **native macOS IPC** (XPC + launchd)
- Avoids global polling, sockets, or custom daemons

This document is intended to be handed directly to a coding agent.

---

## 2. High-level Architecture

```
Client (CLI / tool)
   |
   |  XPC (mach service name)
   v
Directory LaunchAgent (single, named)
   |
   |  hands out XPC endpoints
   v
App Instance (anonymous XPC listener, per instance)
```

Key principles:
- **launchd** provides the single stable name
- **Directory service** acts as a registry
- **Each app instance exposes an anonymous XPC endpoint**
- Clients never talk to instances directly without going through the directory

---

## 3. Components

### 3.1 Directory Service (LaunchAgent)

**Type**: Per-user LaunchAgent

**Responsibilities**:
- Accept XPC connections from:
  - App instances (registration)
  - Clients (discovery + lookup)
- Maintain an in-memory registry:

```
instanceName (String) -> NSXPCListenerEndpoint
```

- Provide discovery APIs
- Remove stale instances when endpoints become invalid

**Does NOT**:
- Execute application logic
- Route commands itself

---

### 3.2 Application Instances

Each running instance of the app:

- Creates its own **anonymous NSXPCListener**
- Exposes an **InstanceProtocol** over XPC
- Chooses or is assigned a unique instance name
- Registers `(instanceName, endpoint)` with the directory service
- Unregisters on clean shutdown (best-effort)

Instances do **not** publish Mach service names.

---

### 3.3 Clients (CLI / tools)

Clients:
- Connect only to the directory service
- Enumerate available instances
- Request an endpoint for a specific instance
- Establish a second XPC connection directly to that instance
- Send commands and receive replies

---

## 4. XPC Protocols

### 4.1 DirectoryProtocol

```swift
@objc protocol DirectoryProtocol {
    func listInstances(reply: @escaping ([String]) -> Void)

    func endpoint(
        for name: String,
        reply: @escaping (NSXPCListenerEndpoint?) -> Void
    )

    func register(
        name: String,
        endpoint: NSXPCListenerEndpoint,
        reply: @escaping (Bool) -> Void
    )

    func unregister(name: String)
}
```

Notes:
- `endpoint(for:)` returns `nil` if instance does not exist
- `register` should reject duplicate names

---

### 4.2 InstanceProtocol

```swift
@objc protocol InstanceProtocol {
    func runCommand(
        _ command: String,
        reply: @escaping (String) -> Void
    )
}
```

Notes:
- Payload type intentionally simple (string-based commands)
- Can later evolve to structured dictionaries or Codable types

---

## 5. LaunchAgent Configuration

### 5.1 Install location

```
~/Library/LaunchAgents/com.example.myapp.directory.plist
```

### 5.2 Required plist keys

- `Label`: `com.example.myapp.directory`
- `ProgramArguments`: path to directory binary
- `MachServices`:

```xml
<key>MachServices</key>
<dict>
  <key>com.example.myapp.directory</key>
  <true/>
</dict>
```

- `RunAtLoad`: true

### 5.3 Lifecycle

- Agent starts at login or on first XPC connection
- Agent runs in user session
- Agent keeps running as long as needed (configurable via `KeepAlive`)

---

## 6. Directory Service Implementation Requirements

### 6.1 Listener

- Use `NSXPCListener(machServiceName:)`
- Export `DirectoryProtocol`

### 6.2 Registry behavior

- In-memory dictionary
- Keys: instance names (String)
- Values: `NSXPCListenerEndpoint`

### 6.3 Cleanup

- Remove entries when:
  - Instance explicitly unregisters
  - Connection to instance fails
  - Endpoint becomes invalid

---

## 7. App Instance Implementation Requirements

- Create anonymous listener using:

```swift
NSXPCListener.anonymous()
```

- Export `InstanceProtocol`
- Call directory `register(name:endpoint:)` on startup
- Call `unregister(name:)` on shutdown (best-effort)

---

## 8. Client Implementation Requirements

- Connect to directory using:

```swift
NSXPCConnection(machServiceName: "com.example.myapp.directory", options: [])
```

- Implement:
  - list
  - select instance
  - send command

---

## 9. Naming Rules

- Instance names must be unique per user
- Directory rejects duplicates
- Naming policy is owned by the application (not directory)

Examples:
- `window-1`
- `project-foo`
- `instance-UUID`

---

## 10. Security Model (Initial)

- Directory accepts all connections from same user
- No cross-user access (enforced by LaunchAgent scope)
- No authentication beyond user session

Future hardening (optional):
- Validate code signature in `shouldAcceptNewConnection`
- Restrict allowed clients by team ID

---

## 11. Non-goals

- System-wide (root) services
- Network transparency
- Persistent storage of registry
- High-throughput streaming

---

## 12. Deliverables for Coding Agent

1. Directory service executable (Swift)
2. LaunchAgent plist
3. Shared protocol definitions
4. Example app instance registration code
5. Example CLI client

---

## 13. Success Criteria

- Multiple app instances can run simultaneously
- Each instance appears in directory listing
- CLI can target a specific instance deterministically
- No hardcoded per-instance Mach service names
- Works reliably across app restarts

---

## 14. Optional Extensions (Out of Scope)

- Versioned protocols
- Structured command schemas
- Async streaming responses
- Sandboxed helper variants

---

End of document.

