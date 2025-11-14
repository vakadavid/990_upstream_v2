#ifndef KSU_SUSFS_H
#define KSU_SUSFS_H

#include <linux/version.h>
#include <linux/types.h>
#include <linux/utsname.h>
#include <linux/hashtable.h>
#include <linux/path.h>
#include <linux/susfs_def.h>

#define SUSFS_VERSION "v1.5.12"
#if LINUX_VERSION_CODE < KERNEL_VERSION(5,0,0)
#define SUSFS_VARIANT "NON-GKI"
#else
#define SUSFS_VARIANT "GKI"
#endif

/*********/
/* MACRO */
/*********/
#define getname_safe(name) (name == NULL ? ERR_PTR(-EINVAL) : getname(name))
#define putname_safe(name) (IS_ERR(name) ? NULL : putname(name))

/**********/
/* STRUCT */
/**********/
/* sus_path */
#ifdef CONFIG_KSU_SUSFS_SUS_PATH
struct st_susfs_sus_path {
	unsigned long                    target_ino;
	char                             target_pathname[SUSFS_MAX_LEN_PATHNAME];
	unsigned int                     i_uid;
};

struct st_susfs_sus_path_list {
	struct list_head                 list;
	struct st_susfs_sus_path         info;
	char                             target_pathname[SUSFS_MAX_LEN_PATHNAME];
	size_t                           path_len;
};

struct st_android_data_path {
	char                             pathname[SUSFS_MAX_LEN_PATHNAME];
	bool                             is_inited;
};

struct st_sdcard_path {
	char                             pathname[SUSFS_MAX_LEN_PATHNAME];
	bool                             is_inited;
};
#endif

/* sus_mount */
#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT
struct st_susfs_sus_mount {
	char                    target_pathname[SUSFS_MAX_LEN_PATHNAME];
	unsigned long           target_dev;
};

struct st_susfs_sus_mount_list {
	struct list_head                        list;
	struct st_susfs_sus_mount               info;
};
#endif

/* sus_kstat */
#ifdef CONFIG_KSU_SUSFS_SUS_KSTAT
struct st_susfs_sus_kstat {
	int                     is_statically;
	unsigned long           target_ino; // the ino after bind mounted or overlayed
	char                    target_pathname[SUSFS_MAX_LEN_PATHNAME];
	unsigned long           spoofed_ino;
	unsigned long           spoofed_dev;
	unsigned int            spoofed_nlink;
	long long               spoofed_size;
	long                    spoofed_atime_tv_sec;
	long                    spoofed_mtime_tv_sec;
	long                    spoofed_ctime_tv_sec;
	long                    spoofed_atime_tv_nsec;
	long                    spoofed_mtime_tv_nsec;
	long                    spoofed_ctime_tv_nsec;
	unsigned long           spoofed_blksize;
	unsigned long long      spoofed_blocks;
};

struct st_susfs_sus_kstat_hlist {
	unsigned long                           target_ino;
	struct st_susfs_sus_kstat               info;
	struct hlist_node                       node;
};
#endif

/* try_umount */
#ifdef CONFIG_KSU_SUSFS_TRY_UMOUNT
struct st_susfs_try_umount {
	char                    target_pathname[SUSFS_MAX_LEN_PATHNAME];
	int                     mnt_mode;
};

struct st_susfs_try_umount_list {
	struct list_head                        list;
	struct st_susfs_try_umount              info;
};
#endif

/* spoof_uname */
#ifdef CONFIG_KSU_SUSFS_SPOOF_UNAME
struct st_susfs_uname {
	char        release[__NEW_UTS_LEN+1];
	char        version[__NEW_UTS_LEN+1];
};
#endif

/* open_redirect */
#ifdef CONFIG_KSU_SUSFS_OPEN_REDIRECT
struct st_susfs_open_redirect {
	unsigned long                    target_ino;
	char                             target_pathname[SUSFS_MAX_LEN_PATHNAME];
	char                             redirected_pathname[SUSFS_MAX_LEN_PATHNAME];
};

struct st_susfs_open_redirect_hlist {
	unsigned long                    target_ino;
	char                             target_pathname[SUSFS_MAX_LEN_PATHNAME];
	char                             redirected_pathname[SUSFS_MAX_LEN_PATHNAME];
	struct hlist_node                node;
};
#endif

/* sus_su */
#ifdef CONFIG_KSU_SUSFS_SUS_SU
struct st_sus_su {
	int         mode;
};
#endif

/* sus_map */
#ifdef CONFIG_KSU_SUSFS_SUS_MAP
struct st_susfs_sus_map {
	char                             target_pathname[SUSFS_MAX_LEN_PATHNAME];
};
#endif

/* susfs_init */
void susfs_init(void);

#endif
