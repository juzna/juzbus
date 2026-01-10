#!/usr/bin/env python3
"""Example: List all registered juzbus instances."""
import asyncio
from juzbus import JuzbusClient, JuzbusError


async def main():
    """List all registered instances."""
    try:
        async with JuzbusClient() as client:
            print("Connecting to juzbus directory...")
            instances = await client.list_instances()

            if instances:
                print(f"\nFound {len(instances)} registered instance(s):")
                for name in instances:
                    print(f"  • {name}")
            else:
                print("\nNo instances registered.")

    except JuzbusError as e:
        print(f"Error: {e}")
        return 1

    return 0


if __name__ == "__main__":
    exit(asyncio.run(main()))
