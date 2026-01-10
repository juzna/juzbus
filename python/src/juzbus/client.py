"""Async client for juzbus XPC directory and instances."""
import asyncio
from typing import List

from ._ffi import ffi, lib
from .exceptions import JuzbusError


class JuzbusClient:
    """Async client for juzbus XPC directory and instances.

    This client connects to the juzbus directory service and allows listing
    registered instances and sending commands to them.

    Example:
        async with JuzbusClient() as client:
            instances = await client.list_instances()
            response = await client.send_command("example-app", "ping")
    """

    def __init__(self):
        """Create a new client connection to the directory service.

        Raises:
            JuzbusError: If client creation fails
        """
        self._client = lib.juzbus_client_create()
        if self._client == ffi.NULL:
            raise JuzbusError("Failed to create juzbus client")
        self._closed = False

    async def list_instances(self) -> List[str]:
        """List all registered instance names.

        Returns:
            List of instance name strings.

        Raises:
            JuzbusError: If listing fails.
        """
        if self._closed:
            raise JuzbusError("Client is closed")

        # Get the current event loop BEFORE creating callback
        loop = asyncio.get_running_loop()
        future = loop.create_future()

        @ffi.callback("void(const char**, size_t, void*)")
        def callback(instances_ptr, count, user_data):
            """Callback invoked from C thread with instance list."""
            try:
                # Copy strings immediately (they're temporary!)
                result = []
                for i in range(count):
                    instance_str = ffi.string(instances_ptr[i]).decode('utf-8')
                    result.append(instance_str)

                # Schedule result on event loop (thread-safe)
                loop.call_soon_threadsafe(future.set_result, result)
            except Exception as e:
                # Handle errors in callback
                loop.call_soon_threadsafe(future.set_exception, JuzbusError(f"Callback error: {e}"))

        # Call C API (non-blocking, callback invoked asynchronously)
        lib.juzbus_client_list_instances(self._client, callback, ffi.NULL)

        # Wait for callback to complete
        return await future

    async def send_command(self, instance_name: str, command: str) -> str:
        """Send a command to a specific instance.

        Args:
            instance_name: Name of the target instance.
            command: Command string to send.

        Returns:
            Response string from the instance.

        Raises:
            JuzbusError: If instance not found or command fails.
        """
        if self._closed:
            raise JuzbusError("Client is closed")

        # Get the current event loop BEFORE creating callback
        loop = asyncio.get_running_loop()
        future = loop.create_future()

        @ffi.callback("void(const char*, const char*, void*)")
        def callback(response_ptr, error_ptr, user_data):
            """Callback invoked from C thread with response or error."""
            try:
                if error_ptr != ffi.NULL:
                    # Error occurred
                    error_msg = ffi.string(error_ptr).decode('utf-8')
                    loop.call_soon_threadsafe(
                        future.set_exception,
                        JuzbusError(error_msg)
                    )
                else:
                    # Success - copy response string (temporary!)
                    if response_ptr != ffi.NULL:
                        response = ffi.string(response_ptr).decode('utf-8')
                    else:
                        response = ""

                    loop.call_soon_threadsafe(future.set_result, response)
            except Exception as e:
                # Handle errors in callback
                loop.call_soon_threadsafe(
                    future.set_exception,
                    JuzbusError(f"Callback error: {e}")
                )

        # Encode strings to UTF-8 bytes
        instance_name_bytes = instance_name.encode('utf-8')
        command_bytes = command.encode('utf-8')

        # Call C API (non-blocking, callback invoked asynchronously)
        lib.juzbus_client_send_command(
            self._client,
            instance_name_bytes,
            command_bytes,
            callback,
            ffi.NULL
        )

        # Wait for callback to complete
        return await future

    async def close(self):
        """Close the client connection and release resources."""
        if not self._closed:
            self._closed = True
            lib.juzbus_client_destroy(self._client)

    async def __aenter__(self):
        """Async context manager entry."""
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit."""
        await self.close()
        return False

    def __del__(self):
        """Destructor - cleanup if not already closed."""
        if not self._closed:
            # Note: Can't use async in __del__, so call sync
            lib.juzbus_client_destroy(self._client)
            self._closed = True
