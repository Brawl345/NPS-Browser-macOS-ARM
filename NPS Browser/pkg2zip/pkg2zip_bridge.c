#include "pkg2zip_bridge.h"
#include "pkg2zip_sys.h"

#include <limits.h>
#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int pkg2zip_main(int argc, char* argv[]);

static jmp_buf gErrorJmp;
static int gErrorJmpActive;
static char gErrorMsg[1024];

const char* pkg2zip_error_message(void)
{
    return gErrorMsg;
}

void pkg2zip_fail(const char* msg, va_list args)
{
    vsnprintf(gErrorMsg, sizeof(gErrorMsg), msg, args);
    if (gErrorJmpActive)
    {
        longjmp(gErrorJmp, 1);
    }
    fputs(gErrorMsg, stderr);
    abort();
}

int pkg2zip_run(const char* working_dir, int argc, char** argv)
{
    char prev_cwd[PATH_MAX];
    if (getcwd(prev_cwd, sizeof(prev_cwd)) == NULL)
    {
        snprintf(gErrorMsg, sizeof(gErrorMsg), "ERROR: cannot get current directory\n");
        return -1;
    }
    if (chdir(working_dir) != 0)
    {
        snprintf(gErrorMsg, sizeof(gErrorMsg), "ERROR: cannot change to '%s' directory\n", working_dir);
        return -1;
    }

    gErrorMsg[0] = 0;
    volatile int result;
    if (setjmp(gErrorJmp) == 0)
    {
        gErrorJmpActive = 1;
        result = pkg2zip_main(argc, argv);
    }
    else
    {
        result = -1;
    }
    gErrorJmpActive = 0;
    chdir(prev_cwd);
    return result;
}
