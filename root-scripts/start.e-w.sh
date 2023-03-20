#!/bin/bash

# Check for required commands
if ! command -v dwarfs >/dev/null 2>&1; then
  echo "dwarfs not installed."
  exit 1
fi
if ! command -v fuse-overlayfs >/dev/null 2>&1; then
  echo "fuse-overlayfs not installed."
  exit 1
fi

# Change to the directory containing the script
cd "$(dirname "$(readlink -f "$0")")" || exit 1

# Check if running as root
if [[ $EUID -eq 0 ]]; then
  echo "This script must not be run as root."
  exit 1
fi

# Set up variables
STS="$PWD/settings.sh"
LOGO="$PWD/logo.txt.gz"
export JCD="${XDG_DATA_HOME:-$HOME/.local/share}/jc141"
mkdir -p "$JCD/wine"

# Set up Wine variables
export WINE="$(command -v wine)"
export WINEPREFIX="$JCD/wine/prefix"
export WINEDLLOVERRIDES="mshtml=d;nvapi,nvapi64=n"
export WINE_LARGE_ADDRESS_AWARE=1

# Mount dwarfs and display logo
bash "$STS" mount-dwarfs
zcat "$LOGO"
echo "Path of the wineprefix is: $WINEPREFIX"

# Auto-unmount

# Check if UNMOUNT variable is set to 0
if [[ "${UNMOUNT:=1}" -eq 0 ]]; then
  echo "Game will not unmount automatically due to user input."
else
  # Define a function to unmount dwarfs and change directory on exit
  function cleanup {
    cd "$OLDPWD" && bash "$STS" unmount-dwarfs
  }
  # Set up a trap to call the cleanup function on exit signals
  trap 'cleanup' EXIT INT SIGINT SIGTERM
  echo "Game will unmount automatically once all child processes close. Can be disabled with UNMOUNT=0."
fi


# Check if vlk-jc141 is installed, and if not, download and install the latest version of vulkan
if ! command -v vlk-jc141 >/dev/null 2>&1; then
  # Define variables
  VLKLOG="$WINEPREFIX/vulkan.log"
  VULKAN="$PWD/vulkan"

  # Define functions
  status-vulkan() {
    if [[ ! -f "$VLKLOG" || -z "$(awk "/^${FUNCNAME[1]}\$/ {print \$1}" "$VLKLOG" 2>/dev/null)" ]]; then
      return 1
    else
      echo "${FUNCNAME[1]} present"
      return 0
    fi
  }
  
  vulkan() {
    # Get the download URL for the latest release of jc141x/vulkan
    DL_URL="$(curl -s https://api.github.com/repos/jc141x/vulkan/releases/latest | awk -F '["]' '/"browser_download_url":/ {print $4}')"
    VLK="$(basename "$DL_URL")"
    # Download and extract the vulkan release, set it up, and clean up
    if [ ! -f "$VLK" ]; then
      if command -v curl >/dev/null 2>&1; then
        curl -LO "$DL_URL" && tar -xvf "$VLK" || { rm "$VLK" && echo "ERROR: Failed to extract vulkan translation." && return 1; }
      else
        echo "ERROR: curl is not installed."
        return 1
      fi
    fi
    rm -rf "$VULKAN" && wineboot -i && bash "$PWD/vulkan/setup-vulkan.sh" && wineserver -w && rm -Rf "$VULKAN"
  }
  
  vulkan-dl() {
    echo "Using external vulkan translation (dxvk,vkd3d,dxvk-nvapi) from github."
    vulkan && echo "$VLKVER" >"$VLKLOG"
  }

  # Check if the vulkan version has changed, and download the latest version if necessary
  VLKVER="$(curl -s -m 5 https://api.github.com/repos/jc141x/vulkan/releases/latest | awk -F '["/]' '/"browser_download_url":/ {print $11}' | cut -c 1-)"
  if [[ ! -f "$VLKLOG" && -z "$(status-vulkan)" ]] || [[ -f "$VLKLOG" && -n "$VLKVER" && "$VLKVER" != "$(awk '{print $1}' "$VLKLOG")" ]]; then
    echo "Vulkan translation is not up-to-date. Updating..."
    vulkan-dl && echo "External vulkan translation is up-to-date."
  fi
fi

# Enable NVAPI for DXVK
export DXVK_ENABLE_NVAPI=1

# block WAN
if command -v bindToInterface.so >/dev/null 2>&1; then
  if [ "${WANBLK:=1}" = "1" ]; then
    export BIND_INTERFACE=lo
    export BIND_EXCLUDE=10.,172.16.,192.168.
    export LD_PRELOAD='/usr/$LIB/bindToInterface.so'
    echo "bindtointerface WAN blocking enabled."
  else
    echo "WAN blocking is not enabled due to user input."
  fi
else
  echo "bindtointerface package not installed, no WAN blocking."
fi

# start
echo "For any misunderstandings or need of support, join the community on Matrix."
if [ "${DBG:=0}" = "1" ]; then
  unset WINEDEBUG
else
  export WINEDEBUG='-all'
  echo "Output muted by default to avoid performance impact. Can unmute with DBG=1."
  exec &>/dev/null
fi
cd "$PWD/files/groot"
"$WINE" "game.exe" "$@"
