#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/kmod.h>
#include <linux/init.h>

// 模块参数：可以在加载时动态修改执行的命令
static char *cmd = "/system/bin/sh -c 'id > /data/local/tmp/ring0_check.txt'";
module_param(cmd, charp, 0000);

static int __init ring0_start(void) {
    int result;
    char *envp[] = { 
        "HOME=/", 
        "TERM=linux", 
        "PATH=/sbin:/vendor/bin:/system/sbin:/system/bin", 
        NULL 
    };
    char *argv[] = { "/system/bin/sh", "-c", cmd, NULL };

    printk(KERN_INFO "Ring0: Attempting to execute in kernel space...\n");

    /* * UMH_WAIT_EXEC: 只要子进程成功启动就返回，不等待执行结束。
     * 这对于高频率或高性能要求的场景非常重要，能避免内核线程挂起。
     */
    result = call_usermodehelper(argv[0], argv, envp, UMH_WAIT_EXEC);

    if (result != 0) {
        printk(KERN_ERR "Ring0: Execution failed with error %d\n", result);
    } else {
        printk(KERN_INFO "Ring0: Command dispatched successfully.\n");
    }

    return 0;
}

static void __exit ring0_end(void) {
    printk(KERN_INFO "Ring0: Module unloaded.\n");
}

module_init(ring0_start);
module_exit(ring0_end);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Gemini_Collaborator");
MODULE_DESCRIPTION("High Performance Ring 0 Command Executor for Android 5.10");
