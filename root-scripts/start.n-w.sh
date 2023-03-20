#!/bin/bash

# Check for required commands
for cmd in dwarfs fuse-overlayfs; do
    command -v $cmd > /dev/null || { echo "$cmd not installed."; exit 1; }
done

# Set working directory to the script's directory
cd "$(dirname "$(readlink -f "$0")")" || exit 1

# Check if running as root
[ "$EUID" = "0" ] && exit 1

# Set environment variables
export JCD="${XDG_DATA_HOME:-$HOME/.local/share}/jc141"
export WINE="$(command -v wine)"
export WINEPREFIX="$JCD/wine/native-prefix"
export WINEDLLOVERRIDES="mshtml=d"
export WINE_LARGE_ADDRESS_AWARE=1
export WINE_D3D_CONFIG="renderer=vulkan"

# Create directory if it doesn't exist
[ ! -d "$JCD/wine" ] && mkdir -p "$JCD/wine"

# Mount dwarfs
bash settings.sh mount-dwarfs

# Display logo
zcat logo.txt.gz

# Display wineprefix path
echo "Path of the wineprefix is: $WINEPREFIX"

# Auto-unmount
if [ "${UNMOUNT:=1}" = "1" ]; then
    function cleanup {
        cd "$OLDPWD" && bash settings.sh unmount-dwarfs
    }
    trap 'cleanup' EXIT INT SIGINT SIGTERM
    echo "Game will unmount automatically once all child processes close. Can be disabled with UNMOUNT=0."
else
    echo "Game will not unmount automatically due to user input."
fi

# Block WAN
if [ -f "/usr/lib64/bindToInterface.so" ] && [ "${WANBLK:=1}" = "1" ]; then
    export BIND_INTERFACE=lo
    export BIND_EXCLUDE=10.,172.16.,192.168.
    export LD_PRELOAD='/usr/$LIB/bindToInterface.so'
    echo "bindtointerface WAN blocking enabled."
else
    echo "WAN blocking is not enabled due to user input."
fi

# Start the game
echo "For any misunderstandings or need of support, join the community on Matrix."
if [ "${DBG:=0}" = "1" ]; then
    echo "Output is not muted. Can mute with DBG=0."
else
    export WINEDEBUG='-all'
    echo "Output muted by default to avoid performance impact. Can unmute with DBG=1."
    exec &>/dev/null
fi
cd files/groot
"$WINE" game.exe "$@"
