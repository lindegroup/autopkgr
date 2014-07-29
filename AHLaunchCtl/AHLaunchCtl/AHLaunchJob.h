//  AHLaunchJob.h
//  Copyright (c) 2014 Eldon Ahrold ( https://github.com/eahrold/AHLaunchCtl )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <Foundation/Foundation.h>
#import "AHLaunchJobSchedule.h"

typedef NS_ENUM(int, AHLaunchDomain) {
    /** User Launch Agents ~/Library/LaunchAgents
   *  loaded by the Console user
   */
    kAHUserLaunchAgent = 1,
    /** Administrator provided LaunchAgents /Library/LaunchAgents/
   *  loaded by the console user
   */
    kAHGlobalLaunchAgent,

    /** Apple provided LaunchDaemons /Library/LaunchAgents/
   *  loaded by root user
   */
    kAHSystemLaunchAgent,

    /** Administrator provided LaunchAgents /Library/LaunchDaemons/
   * loaded by root user
   */
    kAHGlobalLaunchDaemon,

    /** Apple provided LaunchDaemons /Library/LaunchDaemons/
   *  loaded by root user
   */
    kAHSystemLaunchDaemon,
};

/**
 *  Job Object to loaded by AHLaunchCtl.  Conforms to the keys of launchd.plist.
 * See the Apple documentation for more info
 */
@interface AHLaunchJob : NSObject
/**
 *  Label
 */
@property (copy, nonatomic) NSString* Label;
/**
 *  Disabled
 */
@property (nonatomic) BOOL Disabled;
#pragma mark -
/**
 *  Program
 */
@property (copy, nonatomic) NSString* Program;
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSArray* ProgramArguments;
/**
 *  see man launchd.plist
 */
@property (nonatomic) NSInteger StartInterval;

/**
 *  see man launchd.plist  
 */ @property(copy, nonatomic) NSString* ServiceDescription;
#pragma mark -
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSString* UserName;
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSString* GroupName;
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSDictionary* inetdCompatibility;
#pragma mark -
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSArray* LimitLoadToHosts;
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSArray* LimitLoadFromHosts;
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSString* LimitLoadToSessionType;
#pragma mark -
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL EnableGlobbing;
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL EnableTransactions;
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL BeginTransactionAtShutdown;
#pragma mark -
/**
 *  KeepAlive dictionary or Number user @YES and @NO
 */
@property (nonatomic) id KeepAlive;
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL OnDemand;
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL RunAtLoad;
#pragma mark -
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSString* RootDirectory;
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSString* WorkingDirectory;
#pragma mark -
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSDictionary* EnvironmentVariables;
/**
 *  see man launchd.plist
 */
@property (nonatomic) NSInteger Umask;
/**
 *  see man launchd.plist
 */
@property (nonatomic) NSInteger TimeOut;
/**
 *  see man launchd.plist
 */
@property (nonatomic) NSInteger ExitTimeOut;
/**
 *  see man launchd.plist
 */
@property (nonatomic) NSInteger ThrottleInterval;
#pragma mark -
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL InitGroups;
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSArray* WatchPaths;
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSArray* QueueDirectories;
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL StartOnMount;

#pragma mark - Schedule
/**
 * StartCalendarInterval dictionary of integers or array of dictionary of
 * integers
 */
@property (copy, nonatomic) AHLaunchJobSchedule* StartCalendarInterval;
/**
 * Array Of AHLaunchJobSchedule for scheduling mulitple runs with the same
 * Launch Job
 */
@property (copy, nonatomic) NSArray* StartCalendarIntervalArray;

#pragma mark - In/Out
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSString* StandardInPath;
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSString* StandardOutPath;
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSString* StandardErrorPath;
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL Debug;
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL WaitForDebugger;
#pragma mark -
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSDictionary* SoftResourceLimits;
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSDictionary* HardResourceLimits;
#pragma mark -
/**
 *  see man launchd.plist
 */
@property (nonatomic) NSInteger Nice;
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSString* ProcessType;
#pragma mark -
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL AbandonProcessGroup;
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL LowPriorityIO;
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL LowPriorityBackgroundIO;
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL LaunchOnlyOnce;
#pragma mark -
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSDictionary* MachServices;
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSDictionary* Sockets;
#pragma mark - Specialized / Undocumented Apple Keys
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSDictionary* LaunchEvents;
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSDictionary* PerJobMachServices;
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSString* MachExceptionHandler;
#pragma mark -
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSString* POSIXSpawnType;
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSString* PosixSpawnType;
#pragma mark -
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL ServiceIPC;
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL XPCDomainBootstrapper;
#pragma mark -
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSString* CFBundleIdentifier;
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSString* SHAuthorizationRight;
#pragma mark -
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSDictionary* JetsamProperties;
/**
 *  see man launchd.plist
 */
@property (copy, nonatomic) NSArray* BinaryOrderPreference;
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL SessionCreate;
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL MultipleInstances;
#pragma mark -
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL HopefullyExitsLast;
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL ShutdownMonitor;
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL EventMonitor;
/**
 *  see man launchd.plist
 */
@property (nonatomic) BOOL IgnoreProcessGroupAtShutdown;

#pragma mark - Read only properties...
/**
 *  Associated Launch Domain
 */
@property (nonatomic, readonly) AHLaunchDomain domain;
/**
 *  Process ID for the managed executable
 */
@property (nonatomic, readonly) NSInteger PID;
/**
 *  Last exit status of the managed executable
 */
@property (nonatomic, readonly) NSInteger LastExitStatus;
/**
 *  wether or not the curent job is loaded
 */
@property (nonatomic, readonly) BOOL isCurrentlyLoaded;

#pragma mark;
/**
 *  The dictionary value of the Launch Job.
 *
 *  @return The dictionary that will be submitted to launchd
 */
- (NSDictionary*)dictionary;

/**
 *  The version number of the executable if it was compiled with an embedded
 *  Info.plist  This is primairly used for determining the version on a
 *  priviledged helper application
 *
 *  @return Version String Value
 */
- (NSString*)executableVersion;

#pragma mark - Class Methods
/**
 *  Create a job from a dictionary
 *
 *  @param dict dictionary with KVC attributes
 *
 *  @return allocated AHLaunchJob with cooresponding keys
 */
+ (AHLaunchJob*)jobFromDictionary:(NSDictionary*)dict;

/**
 *  Create a job from a launchd.plist
 *
 *  @param file path to launchd.plist
 *
 *  @return allocated AHLaunchJob with cooresponding keys
 */
+ (AHLaunchJob*)jobFromFile:(NSString*)file;

@end
