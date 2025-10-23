#!/bin/bash
#
# clean_before_sync.sh
# 用于在同步 GitHub 之前清理构建缓存、补丁残留、工具链等文件
#

set -e

echo "-----------------------------------------------"
echo "[+] 开始清理项目..."
echo "-----------------------------------------------"

# 清理构建输出目录
if [ -d "out" ]; then
    echo "[-] 删除构建缓存: out/"
    rm -rf out
fi

if [ -d "build/out" ]; then
    echo "[-] 删除构建输出: build/out/"
    rm -rf build/out
fi

# 清理编译生成的中间文件
echo "[-] 删除临时文件（.o .ko .mod .cmd .tmp）..."
find . -type f \( \
    -name "*.o" -o -name "*.ko" -o -name "*.mod" -o -name "*.cmd" -o -name "*.tmp" -o \
    -name "*.symvers" -o -name "*.order" -o -name "*.dwo" -o -name "*.gcno" -o -name "*.gcda" \
\) -delete

# 删除补丁残留文件
echo "[-] 删除 .rej / .orig / .patch 文件..."
find . -type f \( -name "*.rej" -o -name "*.orig" -o -name "*.patch" \) -delete

# 删除 LLVM 工具链（太大，不上传）
if [ -d "toolchain/clang_14" ]; then
    echo "[-] 删除 LLVM Clang 14 工具链..."
    rm -rf toolchain/clang_14
fi

# 删除 ccache 缓存
if [ -d ".ccache" ]; then
    echo "[-] 删除 ccache 缓存..."
    rm -rf .ccache
fi

# 删除自动生成的 dtb/dtbo 文件
find build -type f \( -name "*.dtb" -o -name "*.dtbo" -o -name "*.img" \) -delete

# 删除日志、临时 ZIP 文件
find . -type f \( -name "*.log" -o -name "*.zip" -o -name "*.img" \) -delete

# 删除 git 忽略的文件（如果存在 .gitignore）
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "[-] 清理 Git 忽略文件..."
    git clean -fdX
fi

echo "-----------------------------------------------"
echo "[✔] 清理完成，可以安全同步到 GitHub。"
echo "-----------------------------------------------"

