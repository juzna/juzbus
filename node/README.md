# Juzbus Node.js Bindings

Node.js bindings for macOS XPC services via the Juzbus framework.

## Overview

This package provides Node.js bindings for communicating with XPC services on macOS. It uses a three-layer architecture:

1. **Objective-C Framework** - Wraps native XPC APIs
2. **C ABI** - Provides stable interface between Objective-C and Node.js
3. **Node N-API Addon** - Bridges C to JavaScript with thread-safe callbacks

## Requirements

- macOS 13.0 or later
- Node.js 18.0 or later
- Xcode Command Line Tools
- Swift 5.9 or later

## Installation

```bash
cd node
npm install
```

This will:
1. Build the Objective-C framework (`libJuzbusObjCBridge.dylib`)
2. Copy the framework to the package
3. Build the Node.js native addon

## Usage

### Client (Connecting to Services)

```javascript
const juzbus = require('@juzna/juzbus');

async function example() {
    const client = new juzbus.Client();

    try {
        // List all registered instances
        const instances = await client.listInstances();
        console.log('Instances:', instances);

        // Send a command to an instance
        const response = await client.sendCommand('my-service', 'ping');
        console.log('Response:', response);
    } finally {
        client.close();
    }
}

example();
```

### Service (Registering as a Service)

```javascript
const juzbus = require('@juzna/juzbus');

// Define command handler
function handleCommand(command) {
    if (command === 'ping') return 'pong';
    if (command.startsWith('echo ')) return command.substring(5);
    return `Unknown command: ${command}`;
}

// Create and start service
const service = new juzbus.Service('my-node-service', handleCommand);

if (service.start()) {
    console.log('Service started successfully');

    // Graceful shutdown
    process.on('SIGINT', () => {
        service.stop();
        process.exit(0);
    });
} else {
    console.error('Failed to start service (name may be taken)');
}
```

### API

#### `new Client()`

Creates a new Juzbus client instance.

#### `client.listInstances(): Promise<string[]>`

Lists all registered instance names.

#### `client.sendCommand(instanceName, command): Promise<string>`

Sends a command to a specific instance and returns the response.

- `instanceName` - Name of the instance to send the command to
- `command` - Command string to send

#### `client.close(): void`

Closes the client and releases resources.

#### `new Service(instanceName, commandHandler)`

Creates a new Juzbus service instance.

- `instanceName` - Name to register the service under (must be unique)
- `commandHandler` - Function to invoke when commands are received: `(command: string) => string`

#### `service.start(): boolean`

Starts the service and registers it with the directory.

Returns `true` if the service started successfully, `false` otherwise (e.g., if the name is already taken).

#### `service.stop(): void`

Stops the service and unregisters it from the directory.

## Examples

### Running the Examples

#### Client Example

```bash
# Terminal 1: Start a service (Swift or Node)
juzbus-example alice
# OR
node examples/service.js my-service

# Terminal 2: Run the Node.js client
node examples/client.js
```

The example client will:
- List all registered instances
- Send various commands to the first instance (ping, get-name, get-uptime, echo)

#### Service Example

```bash
# Start the Node.js service
node examples/service.js my-node-service

# In another terminal, send commands to it:
juzbus exec my-node-service ping
juzbus exec my-node-service "echo Hello!"
juzbus exec my-node-service node-version

# Or use the Node.js client:
node examples/client.js
```

The example service will:
- Register with the directory under the specified name
- Handle commands: ping, get-name, get-uptime, echo, node-version, platform, memory, help
- Log received commands and responses

## Architecture

### Threading Model

The bindings use a sophisticated threading model to safely bridge between XPC's async callbacks and Node.js's event loop:

```
XPC Thread → Serial Queue (Obj-C) → C Callback → napi_threadsafe_function → JS Event Loop
```

- Each client has a dedicated serial dispatch queue
- C callbacks execute on a predictable thread
- N-API threadsafe functions safely transition to JavaScript

### Memory Management

- Strings returned from the framework are temporary (valid only during callback)
- JavaScript handles memory automatically via GC
- Native resources are freed when objects are destroyed

## Development

### Building from Source

```bash
# Build Objective-C framework
cd /Users/juzna/projects/juzna/juzbus
swift build -c release --product JuzbusObjCBridge

# Build Node addon
cd node
npm run build
```

### Running Tests

```bash
# Start a test service
juzbus-example test-instance

# Run the client example
npm test
```

## TypeScript Support

TypeScript definitions are included in `lib/index.d.ts`.

```typescript
import { Client } from '@juzna/juzbus';

const client = new Client();
const instances: string[] = await client.listInstances();
```

## Phase 1: Client Support ✅

- ✅ List registered instances
- ✅ Send commands to instances
- ✅ Promise-based async API
- ✅ TypeScript definitions
- ✅ Threadsafe callback handling
- ✅ Example client code
- ✅ Integration with Swift services

## Phase 2: Service Support ✅

- ✅ Register Node.js as an XPC service
- ✅ Receive and handle commands in Node.js
- ✅ Bidirectional Node ↔ Swift communication
- ✅ Synchronous command handling
- ✅ Multiple concurrent client connections
- ✅ Example service code

## Troubleshooting

### dylib Not Found

If you get a "Library not loaded" error, ensure the dylib is in the correct location:

```bash
cd node
bash scripts/copy-dylib.sh
cp lib/libJuzbusObjCBridge.dylib build/Release/
```

### Directory Service Not Running

If you get "connection failed" errors, ensure the Juzbus directory service is running:

```bash
launchctl list | grep juzbus
```

To start it manually:

```bash
juzbus-directory
```

## License

MIT

## Links

- [Juzbus Project](https://github.com/juzna/juzbus)
- [Requirements Document](../docs/requirements/node_bindings.md)
