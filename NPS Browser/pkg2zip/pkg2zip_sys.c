#include "pkg2zip_sys.h"
#include "pkg2zip_utils.h"

#define _FILE_OFFSET_BITS 64
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdarg.h>
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <sys/stat.h>

static int gStdoutRedirected;

void sys_output_init(void)
{
    gStdoutRedirected = !isatty(STDOUT_FILENO);
}

void sys_output_done(void)
{
}

void sys_output(const char* msg, ...)
{
    va_list arg;
    va_start(arg, msg);
    vfprintf(stdout, msg, arg);
    va_end(arg);
}

void sys_error(const char* msg, ...)
{
    va_list arg;
    va_start(arg, msg);
    pkg2zip_fail(msg, arg);
}

static void sys_mkdir_real(const char* path)
{
    if (mkdir(path, S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH) < 0)
    {
        if (errno != EEXIST)
        {
            sys_error("ERROR: cannot create '%s' folder\n", path);
        }
    }
}

sys_file sys_open(const char* fname, uint64_t* size)
{
    int fd = open(fname, O_RDONLY);
    if (fd < 0)
    {
        sys_error("ERROR: cannot open '%s' file\n", fname);
    }

    struct stat st;
    if (fstat(fd, &st) != 0)
    {
        sys_error("ERROR: cannot get size of '%s' file\n", fname);
    }
    *size = st.st_size;

    return (void*)(intptr_t)fd;
}

sys_file sys_create(const char* fname)
{
    int fd = open(fname, O_RDWR | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
    if (fd < 0)
    {
        sys_error("ERROR: cannot create '%s' file\n", fname);
    }

    return (void*)(intptr_t)fd;
}

void sys_close(sys_file file)
{
    if (close((int)(intptr_t)file) != 0)
    {
        sys_error("ERROR: failed to close file\n");
    }
}

void sys_read(sys_file file, uint64_t offset, void* buffer, uint32_t size)
{
    ssize_t read = pread((int)(intptr_t)file, buffer, size, offset);
    if (read < 0 || read != (ssize_t)size)
    {
        sys_error("ERROR: failed to read %u bytes from file\n", size);
    }
}

void sys_write(sys_file file, uint64_t offset, const void* buffer, uint32_t size)
{
    ssize_t wrote = pwrite((int)(intptr_t)file, buffer, size, offset);
    if (wrote < 0 || wrote != (ssize_t)size)
    {
        sys_error("ERROR: failed to write %u bytes to file\n", size);
    }
}

void sys_mkdir(const char* path)
{
    char* last = strrchr(path, '/');
    if (last)
    {
        *last = 0;
        sys_mkdir(path);
        *last = '/';
    }
    sys_mkdir_real(path);
}

void* sys_realloc(void* ptr, size_t size)
{
    void* result = NULL;
    if (!ptr && size)
    {
        result = malloc(size);
    }
    else if (ptr && !size)
    {
        free(ptr);
        return NULL;
    }
    else if (ptr && size)
    {
        result = realloc(ptr, size);
    }
    else
    {
        sys_error("ERROR: internal error, wrong sys_realloc usage\n");
    }

    if (!result)
    {
        sys_error("ERROR: out of memory\n");
    }

    return result;
}

void sys_vstrncat(char* dst, size_t n, const char* format, ...)
{
    char temp[1024];

    va_list args;
    va_start(args, format);
    vsnprintf(temp, sizeof(temp), format, args);
    va_end(args);

    strncat(dst, temp, n - strlen(dst) - 1);
}

static uint64_t out_size;
static uint32_t out_next;

void sys_output_progress_init(uint64_t size)
{
    out_size = size;
    out_next = 0;
}

void sys_output_progress(uint64_t progress)
{
    if (gStdoutRedirected)
    {
        return;
    }

    uint32_t now = (uint32_t)(progress * 100 / out_size);
    if (now >= out_next)
    {
        sys_output("[*] unpacking... %u%%\r", now);
        out_next = now + 1;
    }
}

int sys_test_dir(const char* const path)
{
    struct stat info;

    int statRC = stat(path, &info);
    if (statRC != 0)
    {
        if (errno == ENOENT)  { return 0; }
        if (errno == ENOTDIR) { return 0; }
        return -1;
    }

    return (info.st_mode & S_IFDIR) ? 1 : 0;
}
