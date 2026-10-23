#!/bin/bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  git patch build-essential binutils-aarch64-linux-gnu ncurses-dev libssl-dev bc flex bison rsync kmod cpio \
  python3 ccache tar gzip xz-utils zstd wget curl ca-certificates

# Pin the AOSP Gitiles snapshot that contains clang-r383902.
toolchain_dir="$(pwd)/clang-toolchain"
clang_dir="$toolchain_dir/clang-r383902"
if [[ ! -x "$clang_dir/bin/clang" ]]; then
  rm -rf "$clang_dir"
  mkdir -p "$clang_dir"
  archive_url="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/0e9e7035bf8ad42437c6156e5950eab13655b26c/clang-r383902.tar.gz"
  curl -fL --retry 3 --retry-delay 2 "$archive_url" -o /tmp/clang-r383902.tar.gz
  tar -xzf /tmp/clang-r383902.tar.gz -C "$clang_dir"
fi

clang_bin="$clang_dir/bin"
for tool in clang ld.lld llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-readelf llvm-strip llvm-as; do
  if [[ ! -x "$clang_bin/$tool" ]]; then
    echo "ERROR: expected Android Clang r383902 tool missing: $clang_bin/$tool" >&2
    exit 127
  fi
done

"$clang_bin/clang" --version
"$clang_bin/ld.lld" --version
