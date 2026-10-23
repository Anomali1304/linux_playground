from pathlib import Path

def replace_once(path, old, new, description):
    p = Path(path)
    source = p.read_text()
    if new.strip() in source:
        print(f"[OK] {description}: already present")
        return
    if old not in source:
        raise SystemExit(f"ERROR: cannot locate {description} insertion point in {path}")
    p.write_text(source.replace(old, new, 1))
    print(f"[OK] {description}: inserted")

exec_decl = """#ifdef CONFIG_KSU_MANUAL_HOOK
__attribute__((hot))
extern int ksu_handle_execveat(int *fd, struct filename **filename_ptr,
                               void *argv, void *envp, int *flags);
#endif

"""
exec_needle = "static int do_execveat_common(int fd, struct filename *filename,"
replace_once(
    "fs/exec.c",
    exec_needle,
    exec_decl + exec_needle,
    "execveat declaration",
)

exec_body = "\tint retval;\n\n\tif (IS_ERR(filename))"
exec_replacement = """\tint retval;

#ifdef CONFIG_KSU_MANUAL_HOOK
\tksu_handle_execveat(&fd, &filename, &argv, &envp, &flags);
#endif

\tif (IS_ERR(filename))"""
replace_once("fs/exec.c", exec_body, exec_replacement, "execveat hook")

open_decl = """#ifdef CONFIG_KSU_MANUAL_HOOK
__attribute__((hot))
extern int ksu_handle_faccessat(int *dfd, const char __user **filename_user,
                               int *mode, int *flags);
#endif

"""
open_needle = "SYSCALL_DEFINE3(faccessat, int, dfd, const char __user *, filename, int, mode)"
replace_once("fs/open.c", open_needle, open_decl + open_needle, "faccessat declaration")

open_body = open_needle + "\n{"
open_replacement = open_body + """
#ifdef CONFIG_KSU_MANUAL_HOOK
\tksu_handle_faccessat(&dfd, &filename, &mode, NULL);
#endif"""
replace_once("fs/open.c", open_body, open_replacement, "faccessat hook")
