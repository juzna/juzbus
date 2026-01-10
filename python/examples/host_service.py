#!/usr/bin/env python3
"""Example: Host a juzbus service instance."""
import asyncio
import sys
from datetime import datetime
from juzbus import JuzbusService, JuzbusError


# Service start time
start_time = datetime.now()


async def command_handler(command: str) -> str:
    """Handle commands received by the service.

    Args:
        command: Command string from client

    Returns:
        Response string to send back to client
    """
    command = command.strip()

    if command == "ping":
        return "pong"

    elif command == "status":
        uptime = datetime.now() - start_time
        return f"Python service running. Uptime: {uptime.total_seconds():.1f}s"

    elif command == "version":
        return f"Python {sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"

    elif command.startswith("echo "):
        # Echo back the text after "echo "
        return command[5:]

    elif command == "help":
        return (
            "Available commands:\n"
            "  ping          - Returns 'pong'\n"
            "  status        - Returns service status\n"
            "  version       - Returns Python version\n"
            "  echo <text>   - Echoes back text\n"
            "  help          - Shows this help"
        )

    else:
        return f"Unknown command: {command}. Try 'help' for available commands."


async def main():
    """Main service loop."""
    if len(sys.argv) < 2:
        print("Usage: host_service.py <instance-name>")
        print("\nExample:")
        print("  host_service.py python-service")
        return 1

    instance_name = sys.argv[1]

    try:
        async with JuzbusService(instance_name, command_handler) as service:
            print(f"✓ Service started as '{instance_name}'")
            print("  Listening for commands...")
            print("  Press Ctrl+C to stop\n")

            # Keep the service running until interrupted
            await asyncio.Event().wait()

    except KeyboardInterrupt:
        print("\n\nShutting down...")
        return 0

    except JuzbusError as e:
        print(f"Error: {e}")
        return 1

    return 0


if __name__ == "__main__":
    try:
        exit(asyncio.run(main()))
    except KeyboardInterrupt:
        print("\n\nInterrupted")
        exit(0)
