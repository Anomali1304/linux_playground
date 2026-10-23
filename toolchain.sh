#!/bin/bash
set -Eeuo pipefail

# Use native Arch packages: Ubuntu LLVM archives may require unavailable libtinfo.so.5.
pacman -Syu --noconfirm --needed \
  git patch base-devel ncurses openssl bc flex bison rsync kmod cpio \
  python ccache tar gzip xz zstd wget curl ca-certificates clang llvm lld

for tool in clang ld.lld llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-readelf llvm-strip; do
  command -v "$tool" >/dev/null || { echo "ERROR: required tool '$tool' missing" >&2; exit 127; }
done

clang --version
ld.lld --version
