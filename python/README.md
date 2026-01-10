# juzbus Python Bindings

Python asyncio bindings for the juzbus XPC framework on macOS.

## Installation

```bash
# Install from source (development)
cd python
uv venv
source .venv/bin/activate
uv pip install -e .

# Or install from wheel
uv pip install juzbus-0.1.0-py3-none-any.whl
```

## Requirements

- macOS 13.0+
- Python 3.11+
- juzbus directory service running (`launchctl load ~/Library/LaunchAgents/cz.juzna.juzbus.plist`)

## Quick Start

### List registered instances

```python
import asyncio
from juzbus import JuzbusClient

async def main():
    async with JuzbusClient() as client:
        instances = await client.list_instances()
        print(f"Found {len(instances)} instances:")
        for name in instances:
            print(f"  - {name}")

asyncio.run(main())
```

### Send a command

```python
import asyncio
from juzbus import JuzbusClient

async def main():
    async with JuzbusClient() as client:
        response = await client.send_command("example-app", "ping")
        print(f"Response: {response}")

asyncio.run(main())
```

## Examples

See the `examples/` directory:

- `list_instances.py` - List all registered instances
- `send_command.py` - Send a command to an instance

Run examples:

```bash
# List instances
python examples/list_instances.py

# Send command
python examples/send_command.py example-app ping
python examples/send_command.py example-app "echo hello"
```

## API Reference

### `JuzbusClient`

Async client for connecting to the juzbus directory and instances.

#### Methods

- `__init__()` - Create a new client (connects to directory service)
- `async list_instances() -> List[str]` - List all registered instance names
- `async send_command(instance_name: str, command: str) -> str` - Send command to instance
- `async close()` - Close the client connection

Supports async context manager (`async with`).

### Exceptions

- `JuzbusError` - Base exception
- `ConnectionError` - Failed to connect
- `TimeoutError` - Operation timed out
- `InstanceNotFoundError` - Instance not found
- `RegistrationError` - Service registration failed

## Development

### Building from source

```bash
# Build native library
python build_dylib.py

# Install in development mode
uv pip install -e .

# Run tests (requires juzbus-directory running)
python examples/list_instances.py
```

### Building wheel

```bash
# Build wheel
python build_dylib.py
uv build

# Install wheel
uv pip install dist/juzbus-0.1.0-py3-none-any.whl
```

## Architecture

```
Python Application (asyncio)
   ↓ cffi FFI
Python Binding Layer (juzbus/*.py)
   ↓ Async wrappers
C ABI (libJuzbusObjCBridge.dylib)
   ↓ Objective-C
NSXPCConnection / NSXPCListener
   ↓
macOS XPC System
```

The Python bindings use cffi to load the native Objective-C bridge library, which wraps macOS XPC APIs. All operations are async using Python's asyncio.

## License

MIT
