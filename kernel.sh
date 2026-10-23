#configuration
kernel_source=https://github.com/Anomali1304/android_kernel_xiaomi_camellia.git
branch_kernel=gpu-unlock-1068mhz
defconfig_path=arch/arm64/configs/camellian_gl_defconfig
defconfig=camellian_gl_defconfig

# Toolchain: match build.config.common and build.config.mtk.aarch64 (clang-r383902).
clang_bin="$(pwd)/clang-toolchain/clang-r383902/bin"
export PATH="$clang_bin:$PATH"
for tool in clang ld.lld llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-readelf llvm-strip; do
  command -v "$tool" >/dev/null || { echo "ERROR: $tool not found in Android Clang r383902 toolchain" >&2; exit 127; }
done
clang --version

#Kernel clone
git clone -b $branch_kernel --depth=1 $kernel_source kernel
cd kernel

#Resukisu
curl -LSs "https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/main/kernel/setup.sh" | bash

#KSU config
echo "CONFIG_KSU=y" >> $defconfig_path

# Apply the manual-hook patch intended for Linux 4.14.
echo "CONFIG_KSU_MANUAL_HOOK=y" >> "$defconfig_path"
hook_patch=/tmp/manualhook-v1.6-4.14-openela.patch
curl -fLSs --retry 3 "https://raw.githubusercontent.com/xxblebleblexx/manual_hook_fix/main/manualhook-v1.6-4.14-openela.patch" -o "$hook_patch"
patch --batch --forward -p1 < "$hook_patch"
# Fail early if required manual hooks were not applied.
grep -q 'ksu_handle_execveat' fs/exec.c
grep -q 'ksu_handle_faccessat' fs/open.c
grep -q 'ksu_handle_stat' fs/stat.c
grep -q 'ksu_handle_sys_reboot' kernel/reboot.c

#Nomount driver
echo "CONFIG_NOMOUNT=y" >> $defconfig_path
curl https://raw.githubusercontent.com/maxsteeel/nomount/refs/heads/dev/kernel/setup.sh | bash -

#Run compile
make O=out ARCH=arm64 $defconfig; printf "n\n2\n\n\n\nY\n" | make -j$(nproc --all) CC=clang O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf STRIP=llvm-strip
