#AHLaunchCtl 
Objective-C library for managing launchd
Daemons / Agents.  
It has some simple methods built in 

#Usage 
##Add Job
this will load a job and create the launchd.plist file in the approperiate location

```objective-c
AHLaunchJob* job = [AHLaunchJob new];
job.Program = @"/bin/echo";
job.Label = @"com.eeaapps.echo";
job.ProgramArguments = @[@"hello"];
job.StandardOutPath = @"/tmp/hello.txt";
job.RunAtLoad = YES;
job.StartCalendarInterval = [AHLaunchJobSchedule dailyRunAtHour:2 minute:00];

[[AHLaunchCtl sharedControler] add:job
                          toDomain:kAHUserLaunchAgent
                             error:&error];

                                   
}];  
```

##Remove Job
this will unload a job and remove associated launchd.plist file
```Objective-C
[[AHLaunchCtl sharedControler] remove:@"com.eeaapps.echo"
                           fromDomain:kAHUserLaunchAgent
                                error:&error];
}]; 	 
```

##Load Job
simply load a job, this is good for one off jobs you need executed. 
It will not create a launchd file, but run the specified launchd job as long as the user in logged in (for LaunchAgents) or until the system is rebooted (LaunchDaemons)
```objective-c
AHLaunchJob* job = [AHLaunchJob new];
...(build the job as you would for adding one)...
[[AHLaunchCtl sharedControler] load:job inDomain:kAHGlobalLaunchDaemon error:&error];

```

##Unload Job
Unload a job temporairly, this will not remove the launchd.plist file
```objective-c
[[AHLaunchCtl sharedControler]unload:@"com.eeaapps.echo.helloworld"
                            inDomain:kAHGlobalLaunchDaemon
                               error:&error];
```

##Install PriviledgedHelperTool (Uses SMJobBless)
your helper tool must be properly code signed, and have an embedded Info.plist and Launchd.plist file.** 
```objective-c
	NSError *error;
    [AHLaunchCtl installHelper:kYourHelperToolReverseDomain
    					prompt:@"Install Helper?"
   						 error:&error]; 
    if(error)
    	NSLog(@"error: %@",error);
```
  
**_See the HelperTool_\__CodeSign_\__RunScript.py at the root of this repo, for more details, it's extremely helpfull for getting the proper certificate name and .plists created._ 
 

###There are many more convience methods, see the AHLaunchCtl.h for what's avaliabvle.