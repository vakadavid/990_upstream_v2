#!/bin/bash
# 自动修复 SuSFS 缺失的函数定义，兼容 v1.5.10 - v1.5.12+
# Author: Xtrance / ChatGPT

SUSFS_FILE="fs/susfs.c"

if [ ! -f "$SUSFS_FILE" ]; then
    echo "[-] 未找到 $SUSFS_FILE，请在内核源码根目录下运行此脚本！"
    exit 1
fi

echo "[+] 检查 $SUSFS_FILE 是否缺少 SuSFS 兼容函数..."

# 定义需要检查的函数名
symbols=("susfs_is_current_proc_umounted" "susfs_set_current_proc_umounted" "susfs_reorder_mnt_id")

# 检测并补充缺失的函数
need_patch=false
for sym in "${symbols[@]}"; do
    if ! grep -q "EXPORT_SYMBOL_GPL(${sym})" "$SUSFS_FILE"; then
        echo "[-] 缺少函数定义: ${sym}"
        need_patch=true
    fi
done

if [ "$need_patch" = false ]; then
    echo "[✓] 所有函数已存在，无需修补。"
    exit 0
fi

echo "[+] 开始修补缺失函数..."

cat << 'EOF' >> "$SUSFS_FILE"

// --- SuSFS Compatibility Layer for KernelSU integration ---
// These are safe stubs for compatibility between SuSFS v1.5.10 and v1.5.12+

#ifndef CONFIG_KSU_SUSFS_TRY_UMOUNT
#define CONFIG_KSU_SUSFS_TRY_UMOUNT 1
#endif

bool susfs_is_current_proc_umounted(void)
{
    return false;
}
EXPORT_SYMBOL_GPL(susfs_is_current_proc_umounted);

void susfs_set_current_proc_umounted(void)
{
    // no-op
}
EXPORT_SYMBOL_GPL(susfs_set_current_proc_umounted);

void susfs_reorder_mnt_id(void)
{
    // no-op
}
EXPORT_SYMBOL_GPL(susfs_reorder_mnt_id);

// --- End of Compatibility Layer ---
EOF

echo "[+] 修补完成 ✅"
echo "[i] 现在你可以重新编译内核：make -j$(nproc)"

