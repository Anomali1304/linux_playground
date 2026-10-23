#!/bin/bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  git patch build-essential ncurses-dev libssl-dev bc flex bison rsync kmod cpio \
  python3 ccache tar gzip xz-utils zstd wget curl ca-certificates

# Fetch only the configured Android Clang r383902 directory from a public AOSP mirror.
toolchain_dir="$(pwd)/clang-toolchain"
clang_dir="$toolchain_dir/clang-r383902"
if [[ ! -x "$clang_dir/bin/clang" ]]; then
  rm -rf "$toolchain_dir"
  mkdir -p "$toolchain_dir"
  repo_dir="$toolchain_dir/aosp-clang-repo"
  git clone --depth=1 --filter=blob:none --sparse \
    https://github.com/AOSPA/android_prebuilts_clang_host_linux-x86.git "$repo_dir"
  git -C "$repo_dir" sparse-checkout set clang-r383902
  git -C "$repo_dir" checkout
  if [[ ! -x "$repo_dir/clang-r383902/bin/clang" ]]; then
    echo "ERROR: mirror does not contain clang-r383902/bin/clang" >&2
    exit 127
  fi
  mv "$repo_dir/clang-r383902" "$clang_dir"
  rm -rf "$repo_dir"
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
