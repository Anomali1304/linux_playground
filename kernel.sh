#configuration
kernel_source=https://github.com/Anomali1304/android_kernel_xiaomi_camellia.git
branch_kernel=gpu-unlock-1068mhz
defconfig_path=arch/arm64/configs/camellian_gl_defconfig
defconfig=camellian_gl_defconfig

# Toolchain: match build.config.common and build.config.mtk.aarch64 (clang-r383902).
clang_bin="$(pwd)/clang-toolchain/clang-r383902/bin"
export PATH="$clang_bin:$PATH"
for tool in clang ld.lld llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-readelf llvm-strip llvm-as; do
  command -v "$tool" >/dev/null || { echo "ERROR: $tool not found in Android Clang r383902 toolchain" >&2; exit 127; }
done
clang --version

# Kernel clone
git clone -b "$branch_kernel" --depth=1 "$kernel_source" kernel
cd kernel

# ReSukiSU setup
curl -fLSs --retry 3 "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash

# KSU config
grep -qxF 'CONFIG_KSU=y' "$defconfig_path" || echo 'CONFIG_KSU=y' >> "$defconfig_path"
grep -qxF 'CONFIG_KSU_MANUAL_HOOK=y' "$defconfig_path" || echo 'CONFIG_KSU_MANUAL_HOOK=y' >> "$defconfig_path"

# Apply Linux 4.14 manual hooks, but omit the upstream read_write hook:
# that patch references an undefined fd in vfs_read and is rejected by this KSU tree.
hook_patch=/tmp/manualhook-v1.6-4.14-openela.patch
curl -fLSs --retry 3 "https://raw.githubusercontent.com/xxblebleblexx/manual_hook_fix/main/manualhook-v1.6-4.14-openela.patch" -o "$hook_patch"
python3 - "$hook_patch" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text()
# Parse patch as diff sections and remove only the two incompatible file sections.
parts = text.split("diff --git ")
kept = []
for part in parts:
    if not part:
        continue
    header = part.splitlines()[0]
    if header.startswith("a/fs/read_write.c ") or header.startswith("a/fs/open.c "):
        print("Skipping incompatible manual-hook section:", header)
        continue
    kept.append("diff --git " + part)
if not kept:
    raise SystemExit("ERROR: filtered manual-hook patch is empty")
p.write_text("".join(kept))
PY
# Do not allow a partial/broken patch to silently pass.
if ! patch --batch --forward -p1 < "$hook_patch"; then
  echo "ERROR: manual-hook patch did not apply cleanly; see .rej files above" >&2
  exit 1
fi

# This source tree's faccessat context differs from the published patch; add the hook at the actual call site.
python3 - <<'PY'
from pathlib import Path
p = Path("fs/open.c")
s = p.read_text()
decl = '''#ifdef CONFIG_KSU
__attribute__((hot)) extern int ksu_handle_faccessat(int *dfd, const char __user **filename_user,
                int *mode, int *flags);
#endif

'''
if "ksu_handle_faccessat" not in s:
    marker = "SYSCALL_DEFINE3(faccessat, int, dfd, const char __user *, filename, int, mode)\n{"
    if marker not in s:
        raise SystemExit("ERROR: cannot find faccessat definition in fs/open.c")
    s = s.replace(marker, decl + marker, 1)
    call = "\tif (mode & ~S_IRWXO)"
    if call not in s:
        raise SystemExit("ERROR: cannot find faccessat mode check in fs/open.c")
    s = s.replace(call, "\tksu_handle_faccessat(&dfd, &filename, &mode, NULL);\n\n" + call, 1)
    p.write_text(s)
PY

# Add the required Android 16+ newfstat return hook (ReSukiSU manual-hook checker requires it).
python3 - <<'PY'
from pathlib import Path
p = Path("fs/stat.c")
s = p.read_text()
decl_marker = "#if !defined(__ARCH_WANT_STAT64) || defined(__ARCH_WANT_SYS_NEWFSTATAT)"
decl = """#ifdef CONFIG_KSU_MANUAL_HOOK
extern void ksu_handle_newfstat_ret(unsigned int *fd, struct stat __user **statbuf_ptr);
#if defined(__ARCH_WANT_STAT64) || defined(__ARCH_WANT_COMPAT_STAT64)
extern void ksu_handle_fstat64_ret(unsigned long *fd, struct stat64 __user **statbuf_ptr);
#endif
#endif

"""
if "ksu_handle_newfstat_ret" not in s:
    if decl_marker not in s:
        raise SystemExit("ERROR: cannot find stat declaration insertion point")
    s = s.replace(decl_marker, decl + decl_marker, 1)
needle = "\terror = cp_new_stat(&stat, statbuf);"
call = """\terror = cp_new_stat(&stat, statbuf);
#ifdef CONFIG_KSU_MANUAL_HOOK
\tksu_handle_newfstat_ret(&fd, &statbuf);
#endif"""
if "ksu_handle_newfstat_ret(&fd, &statbuf)" not in s:
    if needle not in s:
        raise SystemExit("ERROR: cannot find newfstat return insertion point")
    s = s.replace(needle, call, 1)
p.write_text(s)
PY

# Ensure all required hooks exist, and the incompatible read hook was not introduced.
grep -q 'ksu_handle_execveat' fs/exec.c
grep -q 'ksu_handle_faccessat' fs/open.c
grep -q 'ksu_handle_stat' fs/stat.c
grep -q 'ksu_handle_sys_reboot' kernel/reboot.c
if grep -q 'ksu_vfs_read_hook' fs/read_write.c; then
  echo "ERROR: incompatible ksu_vfs_read_hook remains in fs/read_write.c" >&2
  exit 1
fi

# NoMount driver
echo "CONFIG_NOMOUNT=y" >> "$defconfig_path"
curl -fLSs --retry 3 "https://raw.githubusercontent.com/maxsteeel/nomount/refs/heads/dev/kernel/setup.sh" | bash -

# Compile
make O=out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CLANG_TRIPLE=aarch64-linux-gnu- "$defconfig" CC=clang HOSTCC=gcc
printf "n\n2\n\n\n\nY\n" | make -j"$(nproc --all)" CC=clang HOSTCC=gcc O=out ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CLANG_TRIPLE=aarch64-linux-gnu- LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf STRIP=llvm-strip
