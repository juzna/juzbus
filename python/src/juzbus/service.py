"""Async service for hosting juzbus XPC instances."""
import asyncio
import ctypes
from typing import Callable, Awaitable

from ._ffi import ffi, lib
from .exceptions import JuzbusError, RegistrationError

# Type alias for command handlers
CommandHandler = Callable[[str], Awaitable[str]]


class JuzbusService:
    """Async service for hosting a juzbus XPC instance.

    This service allows Python applications to register as XPC service instances
    and handle commands from clients.

    Example:
        async def handle_command(command: str) -> str:
            if command == "ping":
                return "pong"
            return f"Unknown command: {command}"

        async with JuzbusService("my-service", handle_command) as service:
            print("Service running...")
            await asyncio.Event().wait()  # Keep running
    """

    def __init__(self, instance_name: str, handler: CommandHandler):
        """Create a new service instance.

        Args:
            instance_name: Unique name for this service instance (alphanumeric, hyphens, underscores)
            handler: Async function that handles commands: (command: str) -> response: str

        Raises:
            JuzbusError: If instance_name is invalid
        """
        self.instance_name = instance_name
        self.handler = handler
        self._service = None
        self._callback_handle = None  # Keep callback alive
        self._started = False

        # Load libc for malloc (Python allocates, C frees)
        try:
            self._libc = ctypes.CDLL("libc.dylib")
            self._libc.malloc.restype = ctypes.c_void_p
            self._libc.strcpy.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
        except Exception as e:
            raise JuzbusError(f"Failed to load libc: {e}") from e

    async def start(self):
        """Start the service and register with the directory.

        This creates an anonymous XPC listener and registers it with the
        juzbus directory service under the instance name.

        Raises:
            JuzbusError: If service creation fails
            RegistrationError: If registration with directory fails
        """
        if self._started:
            raise JuzbusError("Service already started")

        # Get the running event loop BEFORE creating callback
        loop = asyncio.get_running_loop()

        @ffi.callback("void(const char*, char**, void*)")
        def command_callback(command_ptr, out_response, user_data):
            """C callback invoked when command is received.

            This runs on a C thread (not the Python event loop thread).
            We schedule the async handler on the event loop and wait for it.
            """
            try:
                # Decode command
                command = ffi.string(command_ptr).decode('utf-8')

                # Schedule coroutine on event loop and wait for result
                # This BLOCKS the C thread, but that's OK for XPC
                future = asyncio.run_coroutine_threadsafe(self.handler(command), loop)

                try:
                    # Wait for handler to complete (10 second timeout)
                    response = future.result(timeout=10.0)
                except asyncio.TimeoutError:
                    response = "Error: Command handler timed out"
                except Exception as e:
                    response = f"Error: {e}"

                # Allocate response string with malloc (C will free it)
                response_bytes = response.encode('utf-8')
                ptr = self._libc.malloc(len(response_bytes) + 1)
                if ptr == 0:
                    # malloc failed
                    out_response[0] = ffi.NULL
                    return

                self._libc.strcpy(ptr, response_bytes)
                out_response[0] = ffi.cast("char*", ptr)

            except Exception as e:
                # If anything goes wrong, return error message
                error_msg = f"Callback error: {e}".encode('utf-8')
                ptr = self._libc.malloc(len(error_msg) + 1)
                if ptr != 0:
                    self._libc.strcpy(ptr, error_msg)
                    out_response[0] = ffi.cast("char*", ptr)
                else:
                    out_response[0] = ffi.NULL

        # Keep callback alive
        self._callback_handle = command_callback

        # Create service (blocking call)
        loop_for_executor = asyncio.get_running_loop()
        self._service = await loop_for_executor.run_in_executor(
            None,
            lib.juzbus_service_create,
            self.instance_name.encode('utf-8'),
            self._callback_handle,
            ffi.NULL  # user_data
        )

        if self._service == ffi.NULL:
            raise JuzbusError(f"Failed to create service '{self.instance_name}'")

        # Start service (blocking call)
        success = await loop_for_executor.run_in_executor(
            None,
            lib.juzbus_service_start,
            self._service
        )

        if not success:
            # Registration failed - clean up
            await loop_for_executor.run_in_executor(
                None,
                lib.juzbus_service_destroy,
                self._service
            )
            self._service = None
            self._callback_handle = None
            raise RegistrationError(
                f"Failed to register service '{self.instance_name}' "
                f"(name may already be taken)"
            )

        self._started = True

    async def stop(self):
        """Stop the service and unregister from the directory."""
        if not self._started:
            return

        loop = asyncio.get_running_loop()

        # Stop service
        await loop.run_in_executor(None, lib.juzbus_service_stop, self._service)

        # Destroy service
        await loop.run_in_executor(None, lib.juzbus_service_destroy, self._service)

        self._service = None
        self._callback_handle = None
        self._started = False

    async def __aenter__(self):
        """Async context manager entry."""
        await self.start()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit."""
        await self.stop()
        return False

    def __del__(self):
        """Destructor - cleanup if not properly stopped."""
        if self._started and self._service is not None:
            # Can't use async in __del__, so call sync
            lib.juzbus_service_stop(self._service)
            lib.juzbus_service_destroy(self._service)
            self._started = False
