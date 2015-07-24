// BSDProcessInfo.h
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

#import <Foundation/Foundation.h>

@interface BSDProcessInfo : NSObject <NSSecureCoding>

/**
 *  Process Name
 */
@property (copy, nonatomic, readonly) NSString *name;

/**
 *  Process executable path
 */
@property (copy, nonatomic, readonly) NSString *executablePath;

/**
 *  The path for executable used to launch the process.
 */
@property (copy, nonatomic, readonly) NSString *launchPath;

/**
 *  Process Identifier
 */
@property (nonatomic, readonly) pid_t pid;

/**
 *  Parent Process PID
 */
@property (nonatomic, readonly) pid_t parentPid;

/**
 *  Start time of the process
 */
@property (nonatomic, readonly) NSDate *startDate;

/**
 *  Localized string representation of the start date.
 */
@property (nonatomic, readonly) NSDate *startDateString;

/**
 *  Hours the process has been running
 */
@property (nonatomic, readonly) NSString *cpuTime;

/**
 *  Process Arguments
 */
@property (copy, nonatomic, readonly) NSArray *arguments;

/**
 *  String representation of the Process Arguments
 */
@property (copy, nonatomic, readonly) NSString *argumentString;

/**
 *  Process Environment
 */
@property (copy, nonatomic, readonly) NSArray *environment;

/**
 *  Effective User Name
 */
@property (copy, nonatomic, readonly) NSString *effectiveUser;

/**
 *  Effective User ID
 */
@property (nonatomic, readonly) uid_t effectiveUserID;

/**
 *  Real User Name
 */
@property (copy, nonatomic, readonly) NSString *realUser;

/**
 *  Real User ID
 */
@property (nonatomic, readonly) uid_t realUserID;

/**
 *  Whether the process is running
 *  @note this will always return false unless the current user is the owner of
 * the process or root.
 */
@property (nonatomic, readonly) BOOL isRunning;

/**
 *  Create an instance based on known pid
 *
 *  @param pid process pid
 *
 *  @return BSDProcessInfo object
 */
- (instancetype)initWithPid:(pid_t)pid;

/**
 *  Kill The Process
 *  @param sig Signal from signal.h such as SIGHUP or SIGKILL
 *
 *  @return BSD errno
 */
- (int)kill:(int)sig;

#pragma mark - Class Methods
/**
 *  Get all of the running BSD processes on the system
 *
 *  @return Array of BSDProcessInfo objects
 */
+ (NSArray *)allProcesses;

/**
 *  Get the processes with a matching name.
 *  @param name Name of the process to match.
 *
 *  @return Array with matching BSDProcessInfo objects.
 */
+ (NSArray *)allProcessesWithName:(NSString *)name;

/**
 *  Get the process by name. If more than one process with the same name exists
 *it will return the first match.
 *
 *  @param name Name of the process
 *
 *  @return BSDProcessInfo object.
 */
+ (BSDProcessInfo *)processWithName:(NSString *)name;

/**
 *  Get all of the running BSD processes on the system for the current user
 *
 *  @return Array of BSDProcessInfo objects
 */
+ (NSArray *)allUserProcesses;

+ (NSArray *)allUserProcessesWithName:(NSString *)name;
/**
 *  Get the process by name for the current user. If more than one process with
 *the same name exists it will return the first match.
 *
 *  @param name Name of the process
 *
 *  @return BSDProcessInfo object.
 */
+ (BSDProcessInfo *)userProcessWithName:(NSString *)name;

/**
 *  Get the processes with a matching executable path.
 *  @param executablePath file system path of the process to match.
 *
 *  @return Array with matching BSDProcessInfo objects.
 */
+ (NSArray *)allProcessesWithExecutablePath:(NSString *)executablePath;

/**
 *  Get the process by name for the current user. If more than one process with
 *the same name exists it will return the first match.
 *
 *  @param name Name of the process
 *
 *  @return BSDProcessInfo object.
 */
+ (BSDProcessInfo *)processWithExecutablePath:(NSString *)executablePath;

/**
 *  Get the processes with a matching name and containing any number of
 arguments.
 *  @param name Name of the process to match.
 *  @param arguments A list of arguments the process must contain. You do not
 need to specify all arguments, but the return value will send back all matches
 that contain the supplied arguments.

 *
 *  @return Array with matching BSDProcessInfo objects.
 */
+ (NSArray *)allProcessesWithName:(NSString *)name
                matchingArguments:(NSArray *)arguments;

/**
 *  Get a process with a matching name and containing any number of arguments.
 *  @param name Name of the process to match.
 *  @param arguments A list of arguments the process must contain. You do not
 need to specify all arguments, but the return value will send back all matches
 that contain the supplied arguments.

 *
 *  @return BSDProcessInfo object.
 */
+ (BSDProcessInfo *)processWithName:(NSString *)name
                  matchingArguments:(NSArray *)arguments;

/**
 *  Get the process by name for the current user. If more than one process with
 *the same name exists it will return the first match.
 *
 *  @param pid process identifier of the process
 *
 *  @return BSDProcessInfo object.
 */
+ (BSDProcessInfo *)processWithPid:(pid_t)pid;
@end
