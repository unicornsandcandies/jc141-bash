#!/bin/bash
set -euo pipefail

command_exists() {
  command -v "$1" &> /dev/null
}

check_installed() {
  command_exists dwarfs || { echo "dwarfs is not installed." >&2; exit 1; }
  command_exists fuse-overlayfs || { echo "fuse-overlayfs is not installed." >&2; exit 1; }
}

mount_dwarfs() {
  unmount_dwarfs &> /dev/null
  if [ -d "$PWD/files/groot" ] && [ "$(ls -A "$PWD/files/groot")" ]; then
    echo "Game is already mounted or extracted." >&2
    exit 1
  fi
  mkdir -p "$PWD/files/groot"{,-mnt,-rw,-work} && \
    dwarfs "$PWD/files/groot.dwarfs" "$PWD/files/groot-mnt" -o clone_fd -o cache_image && \
    fuse-overlayfs -o lowerdir="$PWD/files/groot-mnt",upperdir="$PWD/files/groot-rw",workdir="$PWD/files/groot-work" "$PWD/files/groot" && \
    echo "Mounted game. Extraction not required. Please report performance issues to us. 'bash settings.sh extract-dwarfs' will make script use extracted files instead."
}

unmount_dwarfs() {
  fuser -k "$PWD/files/groot-mnt"
  fusermount3 -u -z "$PWD/files/groot"
  fusermount3 -u -z "$PWD/files/groot-mnt" && \
    rm -d -f "$PWD/files/groot-mnt" "$PWD/files/groot-work" && \
    echo "Unmounted game."
}

extract_dwarfs() {
  if [ -d "$PWD/files/groot" ] && [ "$(ls -A "$PWD/files/groot")" ]; then
    echo "Game is already mounted or extracted." >&2
    exit 1
  fi
  mkdir "$PWD/files/groot"
  echo "Started extraction process. If the process is closed before the extraction finishes then there will be incomplete files."
  dwarfsextract -i "$PWD/files/groot.dwarfs" -o "$PWD/files/groot"
}

delete_dwarfs() {
  rm -Rf "$PWD/files/groot.dwarfs"
}

compress_to_dwarfs() {
  [ -f "$PWD/files/groot.dwarfs" ] || mkdwarfs -l7 -i "$PWD/files/groot" -o "$PWD/files/groot.dwarfs"
}

check_installed

for i in "$@"; do
  if command_exists "$i"; then
    "$i"
  else
    exit 1
  fi
done
