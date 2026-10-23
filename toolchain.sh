#!/bin/bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  git patch build-essential ncurses-dev libssl-dev bc flex bison rsync kmod cpio \
  python3 ccache tar gzip xz-utils zstd wget curl ca-certificates clang-14 llvm-14 lld-14

for tool in clang ld.lld llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-readelf llvm-strip; do
  command -v "/usr/lib/llvm-14/bin/$tool" >/dev/null || {
    echo "ERROR: LLVM 14 tool '$tool' missing" >&2
    exit 127
  }
done

/usr/lib/llvm-14/bin/clang --version
/usr/lib/llvm-14/bin/ld.lld --version
