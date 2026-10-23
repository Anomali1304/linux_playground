#configuration
kernel_source=https://github.com/Anomali1304/android_kernel_xiaomi_camellia.git
branch_kernel=gpu-unlock-1068mhz
defconfig_path=arch/arm64/configs/camellian_gl_defconfig
defconfig=camellian_gl_defconfig

#Toolchain export (LLVM 18.1.8 from toolchain.sh)
export PATH="/usr/lib/llvm-10/bin:$(pwd)/clang/bin:$PATH"
command -v clang >/dev/null || { echo "ERROR: clang not found; toolchain setup failed" >&2; exit 127; }
command -v ld.lld >/dev/null || { echo "ERROR: ld.lld not found; toolchain setup failed" >&2; exit 127; }
clang --version

#Kernel clone
git clone -b $branch_kernel --depth=1 $kernel_source kernel
cd kernel

#Resukisu
curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash

#KSU config
echo "CONFIG_KSU=y" >> $defconfig_path

#manual hook
echo "CONFIG_KSU_MANUAL_HOOK=y" >> $defconfig_path
wget https://raw.githubusercontent.com/xxblebleblexx/manual_hook_fix/refs/heads/main/resuki-4.19-cip-st.patch; wait; patch -p1 < resuki-4.19-cip-st.patch || true


# Repair the 4.19-targeted external patch for this kernel's actual 4.14 source.
# Keep ReSukiSU manual hooks enabled; fail early if source layout differs.
python3 - <<'PY
from pathlib import Path

p = Path("fs/exec.c")
s = p.read_text()
decl = """#ifdef CONFIG_KSU_MANUAL_HOOK
__attribute__((hot))
extern int ksu_handle_execveat(int *fd, struct filename **filename_ptr,
                               void *argv, void *envp, int *flags);
#endif

"""
needle = "static int do_execveat_common(int fd, struct filename *filename,"
if "ksu_handle_execveat(&fd, &filename, &argv, &envp, &flags);" not in s:
    if needle not in s:
        raise SystemExit("ERROR: cannot locate do_execveat_common in fs/exec.c")
    s = s.replace(needle, decl + needle, 1)
    body = """\tint retval;

\tif (IS_ERR(filename))"""
    replacement = """\tint retval;

#ifdef CONFIG_KSU_MANUAL_HOOK
\tksu_handle_execveat(&fd, &filename, &argv, &envp, &flags);
#endif

\tif (IS_ERR(filename))"""
    if body not in s:
        raise SystemExit("ERROR: cannot locate do_execveat_common hook insertion point")
    s = s.replace(body, replacement, 1)
    p.write_text(s)

p = Path("fs/open.c")
s = p.read_text()
decl = """#ifdef CONFIG_KSU_MANUAL_HOOK
__attribute__((hot))
extern int ksu_handle_faccessat(int *dfd, const char __user **filename_user,
                               int *mode, int *flags);
#endif

"""
needle = "SYSCALL_DEFINE3(faccessat, int, dfd, const char __user *, filename, int, mode)"
if "ksu_handle_faccessat(&dfd, &filename, &mode, NULL);" not in s:
    if needle not in s:
        raise SystemExit("ERROR: cannot locate faccessat syscall in fs/open.c")
    s = s.replace(needle, decl + needle, 1)
    body = needle + "\n{"
    replacement = body + """
#ifdef CONFIG_KSU_MANUAL_HOOK
\tksu_handle_faccessat(&dfd, &filename, &mode, NULL);
#endif"""
    if body not in s:
        raise SystemExit("ERROR: cannot locate faccessat hook insertion point")
    s = s.replace(body, replacement, 1)
    p.write_text(s)

print("Verified/injected ReSukiSU execveat and faccessat manual hooks.")
PY

#Nomount driver
echo "CONFIG_NOMOUNT=y" >> $defconfig_path
curl https://raw.githubusercontent.com/maxsteeel/nomount/refs/heads/dev/kernel/setup.sh | bash -

#Run compile
make O=out ARCH=arm64 $defconfig; printf "n\n2\n\n\n\nY\n" | make -j$(nproc --all) CC=clang O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf STRIP=llvm-strip
