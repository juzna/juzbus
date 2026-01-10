#!/usr/bin/env python3
"""Build script to compile native dylib and copy it to Python package."""
import subprocess
import shutil
import os
from pathlib import Path

def build():
    """Build native library and copy to package directory."""
    script_dir = Path(__file__).parent
    root_dir = script_dir.parent

    # Build native dylib
    print("Building native library...")
    result = subprocess.run(
        ['swift', 'build', '-c', 'release'],
        cwd=root_dir,
        capture_output=True,
        text=True
    )

    if result.returncode != 0:
        print("Build failed:")
        print(result.stdout)
        print(result.stderr)
        raise RuntimeError("Swift build failed")

    print("Build successful!")

    # Copy dylib to package
    src = root_dir / '.build' / 'release' / 'libJuzbusObjCBridge.dylib'
    dst = script_dir / 'src' / 'juzbus' / 'libjuzbus.dylib'

    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(src, dst)
    print(f"Copied {src} -> {dst}")

if __name__ == '__main__':
    build()
