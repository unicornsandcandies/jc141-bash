#!/bin/bash

# Check if required dependencies are installed
command -v dwarfs >/dev/null 2>&1 || { echo >&2 "dwarfs not installed."; exit 1; }
command -v fuse-overlayfs >/dev/null 2>&1 || { echo >&2 "fuse-overlayfs not installed."; exit 1; }

# Change to the directory where the script is located
cd "$(dirname "$(readlink -f "$0")")" || { echo >&2 "Failed to change directory."; exit 1; }

# Check if the script is running as root
[ "$EUID" -eq 0 ] && { echo >&2 "This script cannot be run as root."; exit 1; }

# Set environment variables
export JCD="${XDG_DATA_HOME:-$HOME/.local/share}/jc141"
[ ! -d "$JCD" ] && mkdir -p "$JCD"

# Mount game files using dwarfs
bash "$PWD/settings.sh" mount-dwarfs

# Unmount dwarfs automatically when the script exits
cleanup() {
  cd "$OLDPWD" && bash "$PWD/settings.sh" unmount-dwarfs
}
trap cleanup EXIT INT SIGINT SIGTERM

# Check if WAN blocking is enabled and bindtointerface is installed
if [ -f "/usr/lib64/bindToInterface.so" ] && [ "${WANBLK:=1}" != "0" ]; then
  export BIND_INTERFACE=lo
  export BIND_EXCLUDE=10.,172.16.,192.168.
  export LD_PRELOAD='/usr/$LIB/bindToInterface.so'
  echo "bindtointerface WAN blocking enabled."
else
  echo "WAN blocking is not enabled due to user input or missing package."
fi

# Start the game
echo "For any misunderstandings or need of support, join the community on Matrix."
if [ "${DBG:=0}" != "1" ]; then
  export WINEDEBUG='-all'
  echo "Output muted by default to avoid performance impact. Can unmute with DBG=1."
  exec &>/dev/null
fi
cd "$PWD/files/groot" && ./game.bin "$@"
