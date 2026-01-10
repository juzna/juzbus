#!/usr/bin/env python3
"""Example: Send a command to a juzbus instance."""
import asyncio
import sys
from juzbus import JuzbusClient, JuzbusError


async def main():
    """Send a command to an instance."""
    if len(sys.argv) < 3:
        print("Usage: send_command.py <instance-name> <command>")
        print("\nExample:")
        print("  send_command.py example-app ping")
        print("  send_command.py example-app 'echo hello'")
        return 1

    instance_name = sys.argv[1]
    command = sys.argv[2]

    try:
        async with JuzbusClient() as client:
            print(f"Sending command '{command}' to instance '{instance_name}'...")
            response = await client.send_command(instance_name, command)
            print(f"\nResponse: {response}")

    except JuzbusError as e:
        print(f"Error: {e}")
        return 1

    return 0


if __name__ == "__main__":
    exit(asyncio.run(main()))
