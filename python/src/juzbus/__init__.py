"""Python asyncio bindings for juzbus XPC framework.

juzbus provides async Python bindings to the macOS XPC-based juzbus framework,
allowing Python applications to:
- List and discover registered service instances
- Send commands to service instances
- Host service instances (when service bridge is implemented)

Example:
    import asyncio
    from juzbus import JuzbusClient

    async def main():
        async with JuzbusClient() as client:
            instances = await client.list_instances()
            print(f"Found {len(instances)} instances")

            if instances:
                response = await client.send_command(instances[0], "ping")
                print(f"Response: {response}")

    asyncio.run(main())
"""

from .client import JuzbusClient
from .service import JuzbusService
from .exceptions import (
    JuzbusError,
    ConnectionError,
    TimeoutError,
    InstanceNotFoundError,
    RegistrationError,
)

__version__ = "0.1.0"

__all__ = [
    "JuzbusClient",
    "JuzbusService",
    "JuzbusError",
    "ConnectionError",
    "TimeoutError",
    "InstanceNotFoundError",
    "RegistrationError",
]
