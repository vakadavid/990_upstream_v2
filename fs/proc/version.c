// SPDX-License-Identifier: GPL-2.0
#include <linux/fs.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/utsname.h>
#ifdef CONFIG_KSU_SUSFS_SUS_PROC_VERSION
#include <linux/susfs_def.h>
extern bool susfs_is_current_proc_umounted(void);
#endif

static int version_proc_show(struct seq_file *m, void *v)
{
#ifdef CONFIG_KSU_SUSFS_SUS_PROC_VERSION
	if (likely(susfs_is_current_proc_umounted())) {
		seq_printf(m, SUSFS_FAKE_PROC_VERSION,
			utsname()->sysname,
			utsname()->release,
			SUSFS_FAKE_UTS_VERSION);
		return 0;
	}
#endif
	seq_printf(m, linux_proc_banner,
		utsname()->sysname,
		utsname()->release,
		utsname()->version);
	return 0;
}

static int __init proc_version_init(void)
{
	proc_create_single("version", 0, NULL, version_proc_show);
	return 0;
}
fs_initcall(proc_version_init);
