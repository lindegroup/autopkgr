// BSDProcessInfo.m
//
// Copyright (c) 2015 Eldon Ahrold
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer. Redistributions in binary
// form must reproduce the above copyright notice, this list of conditions and
// the following disclaimer in the documentation and/or other materials
// provided with the distribution. Neither the name of the nor the names of
// its contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#import "BSDProcessInfo.h"

#import <pwd.h>
#import <libproc.h>
#import <sys/sysctl.h>
#import <sys/proc_info.h>

#define PID_TERMINATED -9
typedef struct kinfo_proc kinfo_proc;

@interface BSDProcessInfo ()

@property (nonatomic, readwrite) pid_t pid;
@property (copy, nonatomic, readwrite) NSString *effectiveUser;
@property (nonatomic, readwrite) uid_t effectiveUserID;

@end

@implementation BSDProcessInfo {
    BOOL _argsTried;
    BOOL _envReadPermission;
}

@synthesize name = _name;
@synthesize executablePath = _executablePath;
@synthesize launchPath = _launchPath;
@synthesize arguments = _arguments;
@synthesize argumentString = _argumentString;
@synthesize environment = _environment;

- (NSString *)description {
    NSMutableString *string = [[NSMutableString alloc] init];
    [string appendFormat:@"PID: %d Name %@ User:%@\n",
                         self.pid,
                         self.name,
                         self.effectiveUser];

    [string appendString:@"Command: "];
    if (self.launchPath) {
        [string appendFormat:@"%@ %@", _launchPath, self.argumentString];
    } else {
        [string appendString:self.executablePath];
    }

    return [string copy];
}

#pragma mark - init / dealloc
- (instancetype)initWithkInfoProc:(kinfo_proc *)proc {
    if (self = [super init]) {
        // PID
        self->_pid = proc->kp_proc.p_pid;
        self->_parentPid = proc->kp_eproc.e_ppid;

        // Name
        // Find the executable path...
        char executablePath[PROC_PIDPATHINFO_MAXSIZE];
        bzero(executablePath, PROC_PIDPATHINFO_MAXSIZE);
        proc_pidpath(_pid, executablePath, sizeof(executablePath));

        if (sizeof(executablePath) > 0) {
            self->_executablePath =
                [NSString stringWithUTF8String:executablePath];
        }

        /* p_comm maxes out at 16 characters, so if it's there, it's most
         * likely too long to be correct, so use the executable path. */
        if (strlen(proc->kp_proc.p_comm) >= 16 && _executablePath.length) {
            self->_name = _executablePath.lastPathComponent;
        } else {
            self->_name = [NSString stringWithUTF8String:proc->kp_proc.p_comm];
        }

        // CPU
        self->_startDate = [NSDate
            dateWithTimeIntervalSince1970:(proc->kp_proc.p_starttime.tv_sec)];

        // User
        int eUid = proc->kp_eproc.e_ucred.cr_uid;
        struct passwd *user = getpwuid(eUid);
        if (user) {
            self->_effectiveUserID = eUid;
            self->_effectiveUser =
                [NSString stringWithFormat:@"%s", user->pw_name];
        }

        int rUid = proc->kp_eproc.e_pcred.p_ruid;
        struct passwd *realUser = getpwuid(rUid);
        if (realUser) {
            self->_realUserID = rUid;
            self->_realUser =
            [NSString stringWithFormat:@"%s", realUser->pw_name];
        }


        // Private
        _envReadPermission = (getuid() == 0) || (rUid == getuid());
    }

    return self;
}

- (instancetype)initWithPid:(pid_t)pid {
    struct kinfo_proc proc;
    size_t buffer = sizeof(proc);

    const u_int lenght = 4;
    int path[lenght] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, pid };

    int sysctlResult = sysctl(path, lenght, &proc, &buffer, NULL, 0);

    // If sysctl did not fail and process with PID available - take UID.
    if ((sysctlResult == 0) && (buffer != 0)) {
        return [self initWithkInfoProc:&proc];
    }

    return nil;
}

#pragma mark - Accessors

- (NSString *)startDateString {
    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [dateFormatter setTimeStyle:NSDateFormatterLongStyle];
    [dateFormatter setLocale:[NSLocale currentLocale]];
    return [dateFormatter stringFromDate:_startDate];
}

- (NSString *)launchPath {
    if (!_launchPath) {
        if (![self arguments]) {
            /* _invokedExecutable is set during `-arguments`
             * so if that returned NIL, then set it to the executablePath */
            _launchPath = _executablePath;
        }
    }
    return _launchPath;
};

- (NSArray *)arguments {
    /* Adapted from ps source code.
     * http://www.opensource.apple.com/source/adv_cmds/adv_cmds-158/ps/ps.c */

    if (self.pid && !_arguments && !_argsTried) {
        _argsTried = YES;
        NSMutableArray *arguments;
        NSMutableArray *environment;

        int mib[3], argmax, nargs, c = 0;
        size_t size;
        char *procargs, *sp, *np, *cp;

        mib[0] = CTL_KERN;
        mib[1] = KERN_ARGMAX;

        size = sizeof(argmax);
        if (sysctl(mib, 2, &argmax, &size, NULL, 0) == -1) {
            goto ERROR_A;
        }

        /* Allocate space for the arguments. */
        procargs = (char *)malloc(argmax);
        if (procargs == NULL) {
            goto ERROR_A;
        }

        mib[0] = CTL_KERN;
        mib[1] = KERN_PROCARGS2;
        mib[2] = _pid;

        size = (size_t)argmax;
        if (sysctl(mib, 3, procargs, &size, NULL, 0) == -1) {
            goto ERROR_B;
        }

        memcpy(&nargs, procargs, sizeof(nargs));
        cp = procargs + sizeof(nargs);

        /* Skip the saved exec_path. */
        for (; cp < &procargs[size]; cp++) {
            if (*cp == '\0') {
                /* End of exec_path reached. */
                break;
            }
        }

        if (cp == &procargs[size]) {
            goto ERROR_B;
        }

        /* Skip trailing '\0' characters. */
        for (np = NULL; cp < &procargs[size]; cp++) {
            if (*cp != '\0') {
                if (np != NULL) {
                    *np = ' ';

                    /* The path used to invoke the command could be
                     * different then the executable path, such as
                     * with shebang. */
                    _launchPath = [[NSString stringWithUTF8String:np]
                        stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceCharacterSet]];
                }
                /* Beginning of first argument reached. */
                break;
            }
            /* Note location of current '\0'. */
            np = cp;
        }

        if (cp == &procargs[size]) {
            goto ERROR_B;
        }
        /* Save where the argv[0] string starts. */
        sp = cp;

        /*
         * Iterate through the '\0'-terminated strings and convert '\0' to ' '
         * until a string is found that has a '=' character in it (or there are
         * no more strings in procargs).  There is no way to deterministically
         * know where the command arguments end and the environment strings
         * start, which is why the '=' character is searched for as a heuristic.
         */

        for (np = NULL; c < nargs && cp < &procargs[size]; cp++) {
            if (*cp == '\0') {
                c++;
                if (np != NULL) {
                    /* Convert previous '\0'. */
                    *np = ' ';

                    if (!arguments) {
                        arguments = [[NSMutableArray alloc]
                            initWithCapacity:KERN_ARGMAX];
                    }

                    [arguments
                        addObject:
                            [[NSString stringWithUTF8String:np]
                                stringByTrimmingCharactersInSet:
                                    [NSCharacterSet whitespaceCharacterSet]]];
                }

                /* Note location of current '\0'. */
                np = cp;
            }
        }

        /*
         * If eflg is non-zero, continue converting '\0' characters to ' '
         * characters until no more strings that look like environment settings
         * follow.
         */
        if (_envReadPermission) {
            for (; cp < &procargs[size]; cp++) {
                if (*cp == '\0') {
                    if (np != NULL) {
                        if (&np[1] == cp) {
                            /*
                             * Two '\0' characters in a row.
                             * This should normally only
                             * happen after all the strings
                             * have been seen, but in any
                             * case, stop parsing.
                             */
                            break;
                        }
                        /* Convert previous '\0'. */
                        *np = ' ';

                        if (!environment) {
                            environment =
                                [NSMutableArray arrayWithCapacity:KERN_ARGMAX];
                        }
                        NSArray *a = [[NSString stringWithUTF8String:np]
                            componentsSeparatedByString:@"="];
                        if (a.count == 2) {
                            NSCharacterSet *cs = [NSCharacterSet
                                    whitespaceAndNewlineCharacterSet];
                            [environment
                                addObject:
                                    @{
                                           [a[0] stringByTrimmingCharactersInSet
                                            : cs] : [a[1]
                                               stringByTrimmingCharactersInSet:
                                                   cs]
                                    }];
                        }
                    }
                    /* Note location of current '\0'. */
                    np = cp;
                }
            }
        }

        /*
         * sp points to the beginning of the arguments/environment string, and
         * np should point to the '\0' terminator for the string.
         */
        if ((np != NULL) && (np != sp)) {
            _arguments = [arguments copy];
            _environment = [environment copy];
        }

    ERROR_B:
        /* Clean up. */
        free(procargs);
    }
ERROR_A:
    return _arguments;
}

- (NSString *)argumentString {
    if (!_argumentString && self.arguments) {
        _argumentString = [_arguments componentsJoinedByString:@" "] ?: @"";
    }
    return _argumentString;
}

- (NSArray *)environment {
    if (!_environment) {
        /* The environment is constructed during the `-arguments` method. */
        [self arguments];
    }
    return _environment;
}

- (NSString *)cpuTime {
    unsigned int unitFlags = NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;

    NSDateComponents *components =
        [[NSCalendar currentCalendar] components:unitFlags
                                        fromDate:self.startDate
                                          toDate:[NSDate date]
                                         options:0];

    NSMutableString *cpuTime = [[NSMutableString alloc] initWithCapacity:64];
    if ([components day]) {
        [cpuTime appendFormat:@"%ld:", [components day]];
    }

    [cpuTime appendFormat:@"%ld:%ld:%ld",
     (long)[components hour],
     (long)[components minute],
     (long)[components second]];

    return cpuTime;
}

- (BOOL)isRunning {
    return (kill(_pid, 0) == 0);
}

#pragma mark - Methods
- (int)kill:(int)sig {
    int rc = 0;
    if ((_pid != PID_TERMINATED) && ((rc = kill(_pid, sig)) == 0)) {
        _pid = PID_TERMINATED;
    }
    return rc;
}

#pragma mark - Getting Filtered Processes
#pragma mark-- Name

+ (NSArray *)allProcessesWithName:(NSString *)name {
    NSPredicate *predicate =
        [NSPredicate predicateWithFormat:@"%K == %@",
                                         NSStringFromSelector(@selector(name)),
                                         name];

    return [[self __allProcesses] filteredArrayUsingPredicate:predicate];
}

+ (BSDProcessInfo *)processWithName:(NSString *)name {
    return [[self allProcessesWithName:name] firstObject];
}

+ (NSArray *)allUserProcessesWithName:(NSString *)name {
    NSPredicate *predicate = [NSPredicate
        predicateWithFormat:@"%K == %@",
                            NSStringFromSelector(@selector(effectiveUser)),
                            NSUserName()];

    return [[self __userProcesses] filteredArrayUsingPredicate:predicate];
}

+ (BSDProcessInfo *)userProcessWithName:(NSString *)name {
    return [[self allUserProcessesWithName:name] firstObject];
}

#pragma mark-- Name and Args
+ (NSArray *)allProcessesWithName:(NSString *)name
                matchingArguments:(NSArray *)arguments {
    NSMutableArray *procArray = [self __allProcesses];
    NSMutableArray *tmpArray =
        [NSMutableArray arrayWithCapacity:procArray.count];

    for (BSDProcessInfo *info in procArray) {
        BOOL addItem = YES;
        if ([info.name isEqualToString:name]) {
            for (NSString *arg in arguments) {
                if (![info.arguments containsObject:arg]) {
                    addItem = NO;
                    break;
                }
            }
        } else {
            addItem = NO;
        }

        if (addItem) {
            [tmpArray addObject:info];
        }
    }

    return [tmpArray copy];
}

+ (BSDProcessInfo *)processWithName:(NSString *)name
                  matchingArguments:(NSArray *)arguments {
    return [[self allProcessesWithName:name
                     matchingArguments:arguments] firstObject];
}

#pragma mark-- Executable Path
+ (NSArray *)allProcessesWithExecutablePath:(NSString *)executablePath {
    NSPredicate *predicate = [NSPredicate
        predicateWithFormat:@"%K == %@",
                            NSStringFromSelector(@selector(executablePath)),
                            executablePath];

    return [[self __allProcesses] filteredArrayUsingPredicate:predicate];
}

+ (BSDProcessInfo *)processWithExecutablePath:(NSString *)executablePath {
    return [[self allProcessesWithExecutablePath:executablePath] firstObject];
}

#pragma mark - Getting Processes
+ (BSDProcessInfo *)processWithPid:(pid_t)pid {
    return [[[self class] alloc] initWithPid:pid];
}

+ (NSArray *)allUserProcesses {
    return [[self __userProcesses] copy];
}

+ (NSArray *)allProcesses {
    return [[self __allProcesses] copy];
}

+ (NSMutableArray *)__userProcesses {
    NSPredicate *predicate = [NSPredicate
        predicateWithFormat:@"%K == %@",
                            NSStringFromSelector(@selector(effectiveUser)),
                            NSUserName()];

    NSMutableArray *array = [self __allProcesses];
    [array filterUsingPredicate:predicate];
    return array;
}

+ (NSMutableArray *)__allProcesses {
    // This is simply an Objective-c wrapper for this...
    // http://psutil.googlecode.com/svn/trunk/psutil/arch/bsd/process_info.c
    // Copyright (c) 2009, Jay Loden, Giampaolo Rodola'. All rights reserved.
    // Use of this source code is governed by a BSD-style license that can be
    // found in the LICENSE file.

    /* Returns a list of all BSD processes on the system.  This routine
     * allocates the list and puts it in *procList and a count of the
     * number of entries in *procCount.  You are responsible for freeing
     * this list (use "free" from System framework).
     * On success, the function returns 0.
     * On error, the function returns a BSD errno value. */

    NSMutableArray *processes = nil;

    int err;
    kinfo_proc *result;
    bool done;
    const int name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };

    /* Declaring name as const requires us to cast it when passing it to
     * sysctl because the prototype doesn't include the const modifier. */
    size_t length;

    /* We start by calling sysctl with result == NULL and length == 0.
     * That will succeed, and set length to the appropriate length.
     * We then allocate a buffer of that size and call sysctl again
     * with that buffer.  If that succeeds, we're done.  If that fails
     * with ENOMEM, we have to throw away our buffer and loop.  Note
     * that the loop causes use to call sysctl with NULL again; this
     * is necessary because the ENOMEM failure case sets length to
     * the amount of data returned, not the amount of data that
     * could have been returned. */

    result = NULL;
    done = false;
    do {
        assert(result == NULL);

        // Call sysctl with a NULL buffer.
        length = 0;
        err = sysctl((int *)name,
                     (sizeof(name) / sizeof(*name)) - 1,
                     NULL,
                     &length,
                     NULL,
                     0);
        if (err == -1) {
            err = errno;
        }

        /* Allocate an appropriately sized buffer based
         * on the results from the previous call. */

        if (err == 0) {
            result = malloc(length);
            if (result == NULL) {
                err = ENOMEM;
            }
        }

        /* Call sysctl again with the new buffer.  If we get an ENOMEM
         * error, toss away our buffer and start again. */

        if (err == 0) {
            err = sysctl((int *)name,
                         (sizeof(name) / sizeof(*name)) - 1,
                         result,
                         &length,
                         NULL,
                         0);

            if (err == -1) {
                err = errno;
            }
            if (err == 0) {
                done = true;
            } else if (err == ENOMEM) {
                assert(result != NULL);
                free(result);
                result = NULL;
                err = 0;
            }
        }
    } while (err == 0 && !done);

    /* Check the result and built the NSArray */
    if (result != NULL) {
        if (err == 0) {
            size_t rlenght = (length / sizeof(kinfo_proc));

            processes = [NSMutableArray arrayWithCapacity:rlenght];
            for (int i = 0; i < rlenght; i++) {
                struct kinfo_proc *proc = &result[i];

                BSDProcessInfo *info;
                if ((info = [[self alloc] initWithkInfoProc:proc])) {
                    [processes addObject:info];
                };
            }
        }

        // Clean-up
        free(result);
        result = NULL;
    }

    assert((err == 0) == (processes != NULL));
    return processes;
}

#pragma mark - Secure coding

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        // PID
        self->_pid =
            [decoder decodeInt32ForKey:NSStringFromSelector(@selector(pid))];
        self->_parentPid = [decoder
            decodeInt32ForKey:NSStringFromSelector(@selector(parentPid))];

        // Process Name
        self->_executablePath =
            [decoder decodeObjectOfClass:[NSString class]
                                  forKey:NSStringFromSelector(
                                             @selector(executablePath))];
        self->_name =
            [decoder decodeObjectOfClass:[NSString class]
                                  forKey:NSStringFromSelector(@selector(name))];

        // Arguments - Environment
        self->_arguments = [decoder
            decodeObjectOfClass:[NSArray class]
                         forKey:NSStringFromSelector(@selector(arguments))];
        self->_environment = [decoder
            decodeObjectOfClass:[NSDictionary class]
                         forKey:NSStringFromSelector(@selector(environment))];
        self->_launchPath = [decoder
            decodeObjectOfClass:[NSString class]
                         forKey:NSStringFromSelector(@selector(launchPath))];

        // CPU
        self->_startDate = [decoder
            decodeObjectOfClass:[NSDate class]
                         forKey:NSStringFromSelector(@selector(startDate))];

        // User
        self->_effectiveUser = [decoder
            decodeObjectOfClass:[NSString class]
                         forKey:NSStringFromSelector(@selector(effectiveUser))];

        self->_effectiveUserID = [decoder
            decodeInt32ForKey:NSStringFromSelector(@selector(effectiveUserID))];
        // User
        self->_realUser = [decoder
            decodeObjectOfClass:[NSString class]
                         forKey:NSStringFromSelector(@selector(realUser))];

        self->_realUserID = [decoder
            decodeInt32ForKey:NSStringFromSelector(@selector(realUserID))];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    // PID
    [coder encodeInt32:self.pid forKey:NSStringFromSelector(@selector(pid))];
    [coder encodeInt32:self.parentPid
                forKey:NSStringFromSelector(@selector(parentPid))];

    // Process Name
    [coder encodeObject:self.name forKey:NSStringFromSelector(@selector(name))];
    [coder encodeObject:self.executablePath
                 forKey:NSStringFromSelector(@selector(executablePath))];

    // Arguments - Environment
    [coder encodeObject:self.arguments
                 forKey:NSStringFromSelector(@selector(arguments))];
    [coder encodeObject:self.environment
                 forKey:NSStringFromSelector(@selector(environment))];
    [coder encodeObject:self.launchPath
                 forKey:NSStringFromSelector(@selector(launchPath))];

    // CPU
    [coder encodeObject:self.startDate
                 forKey:NSStringFromSelector(@selector(startDate))];

    // User
    [coder encodeObject:self.effectiveUser
                 forKey:NSStringFromSelector(@selector(effectiveUser))];
    [coder encodeInt32:self.effectiveUserID
                forKey:NSStringFromSelector(@selector(effectiveUserID))];

    [coder encodeObject:self.realUser
                 forKey:NSStringFromSelector(@selector(realUser))];
    [coder encodeInt32:self.realUserID
                forKey:NSStringFromSelector(@selector(realUserID))];

}

@end
