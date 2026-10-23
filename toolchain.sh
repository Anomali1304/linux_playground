#!/bin/bash
set -Eeuo pipefail

# The workflow runs inside the Arch Linux container as root.
pacman -Syu --noconfirm --needed \
  git patch base-devel ncurses openssl bc flex bison rsync kmod cpio \
  python ccache tar gzip xz zstd wget curl ca-certificates

LLVM_VERSION="18.1.8"
LLVM_ARCHIVE="clang+llvm-${LLVM_VERSION}-x86_64-linux-gnu-ubuntu-18.04.tar.xz"
LLVM_URL="https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/${LLVM_ARCHIVE}"

mkdir -p clang
curl --fail --location --retry 3 --retry-all-errors "${LLVM_URL}" --output "/tmp/${LLVM_ARCHIVE}"
tar -xJf "/tmp/${LLVM_ARCHIVE}" --strip-components=1 -C clang
rm -f "/tmp/${LLVM_ARCHIVE}"

export PATH="$(pwd)/clang/bin:$PATH"
for tool in clang ld.lld llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-readelf llvm-strip; do
  command -v "$tool" >/dev/null || { echo "ERROR: required tool '$tool' missing" >&2; exit 127; }
done

clang --version
ld.lld --version
