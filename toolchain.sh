#!/bin/bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  git patch build-essential ncurses-dev libssl-dev bc flex bison rsync kmod cpio \
  python3 ccache tar gzip xz-utils zstd wget curl ca-certificates

# Match the kernel repository's build.config.common / build.config.mtk.aarch64:
# CLANG_PREBUILT_BIN=.../clang-r383902/bin
toolchain_dir="$(pwd)/clang-toolchain"
if [[ ! -x "$toolchain_dir/clang-r383902/bin/clang" ]]; then
  rm -rf "$toolchain_dir"
  git clone --depth=1 --filter=blob:none --sparse \
    https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86.git \
    "$toolchain_dir"
  git -C "$toolchain_dir" sparse-checkout set clang-r383902
fi

clang_bin="$toolchain_dir/clang-r383902/bin"
for tool in clang ld.lld llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-readelf llvm-strip; do
  if [[ ! -x "$clang_bin/$tool" ]]; then
    echo "ERROR: expected Android Clang r383902 tool missing: $clang_bin/$tool" >&2
    exit 127
  fi
done

"$clang_bin/clang" --version
"$clang_bin/ld.lld" --version
