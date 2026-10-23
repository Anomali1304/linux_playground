#configuration
kernel_source=https://github.com/Anomali1304/android_kernel_xiaomi_camellia.git
branch_kernel=gpu-unlock-1068mhz
defconfig_path=arch/arm64/configs/camellian_gl_defconfig
defconfig=camellian_gl_defconfig

#Toolchain export (LLVM 18.1.8 from toolchain.sh)
export PATH="$(pwd)/clang/bin:$PATH"
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
wget https://raw.githubusercontent.com/xxblebleblexx/manual_hook_fix/refs/heads/main/resuki-4.19-cip-st.patch;wait;patch -p1 < resuki-4.19-cip-st.patch

#Nomount driver
echo "CONFIG_NOMOUNT=y" >> $defconfig_path
curl https://raw.githubusercontent.com/maxsteeel/nomount/refs/heads/dev/kernel/setup.sh | bash -

#Run compile
make O=out ARCH=arm64 $defconfig; printf "n\n2\n\n\n\nY\n" | make -j$(nproc --all) CC=clang O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 LD=ld.lld AS=llvm-as AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf STRIP=llvm-strip
