#import "SSHTool.h"

#import "PreferenceController.h"

#include <unistd.h>

@implementation SSHTool

/* Construct a SSHTool object for the required tool. */
+ (id)toolWithName:(NSString *)toolname
{
	return [self toolWithPath:[[[NSUserDefaults standardUserDefaults] 
					stringForKey:SSHToolsPathString] 
					stringByAppendingPathComponent:toolname]];
}

/* Construct a SSHTool object for the required path. */
+ (id)toolWithPath:(NSString *)path
{
	SSHTool *tool = [[[self alloc] init] autorelease];
	[tool setPath:path];
	return tool;
}

- (id)init
{
	if (! (self = [super init]))
		return nil;
		
	terminated = NO;
	observing = NO;
	task = [[NSTask alloc] init];
	[task setStandardInput:[NSFileHandle fileHandleWithNullDevice]];

	return self;
}

- (void)dealloc
{
        if (observing)
	{
		observing = FALSE;
		[[NSNotificationCenter defaultCenter] removeObserver:self];
	}
	
	[task release];
	task = nil;
	[toolPath release];
        toolPath = nil;
	[terminateObject release];
        terminateObject = nil;
	[terminateInfo release];
	terminateInfo = nil;
	
	[super dealloc];
}

/* Set the path. */
- (void)setPath:(NSString *)path
{
	NSString *oldPath = toolPath;
	toolPath = [path copy];
	[oldPath release];
}

/* Set the argument for the NSTask. */
- (void)setArgument:(NSString *)argument
{
	[task setArguments:[NSArray arrayWithObject:argument]];
}

/* Set the arguments for the NSTask. */
- (void)setArguments:(NSArray *)arguments
{
	[task setArguments:[NSArray arrayWithArray:arguments]];
}

/* Return the task object. */
- (NSTask *)task
{
	return task;
}

/* Add environment variable. */
- (void)setEnvironmentVariable:(NSString *)variable withValue:(NSString *)value
{
	if (!variable || !value)
		return;

	NSMutableDictionary *env = [[task environment] mutableCopy];
	if (! env)
		env = [[NSMutableDictionary alloc] init];

	[env setObject:value forKey:variable];
	[task setEnvironment:env];
	[env release];
}

/* Launch and return the stdout as an NSString. */
- (NSString *)launchForStandardOutput
{
	NSPipe *thePipe = [[[NSPipe alloc] init] autorelease];

	[task setStandardOutput:thePipe];

	if (![self launchAndWait])
	{
		return nil;
	}

	/* Put the data from thePipe to theOutput. */
	NSData *theOutput = [[thePipe fileHandleForReading] readDataToEndOfFile];
	return [[[NSString alloc] initWithData:theOutput encoding:NSUTF8StringEncoding] autorelease];
}

/* Launch and wait until exit, returning a BOOL to report success or failure. */
- (BOOL)launchAndWait
{
	BOOL term_status;
	if (![self launch])
	{
		return NO;
	}
	
	[task waitUntilExit];
        term_status = ![task terminationStatus];
	return term_status;
}

/* Launch. */
- (BOOL)launch
{
        if (terminated)
		return(NO);
	/* Let's see if the path is accessible. */
	if (![[NSFileManager defaultManager] isExecutableFileAtPath:toolPath])
		return NO;

	/* Set the launchpath to the path instance variable. */
	[task setLaunchPath:toolPath];
	
	BOOL retValue = YES;
	NS_DURING
		[task launch];
	NS_HANDLER
		if ([[localException name] isEqualToString:NSInvalidArgumentException])
			retValue = NO;
		
		else
			[localException raise];
	NS_ENDHANDLER
	
	return retValue;
}

/* Terminate. */
- (void)terminate
{
	if (!terminated)
	{
        	terminated = YES;
		[task terminate];
	}
}

/* Handle terminate notifications. */
- (void)handleTerminateWithSelector:(SEL)theSelector toObject:(id)theObject withInfo:(id)theInfo
{
	if (!theSelector || !theObject) 
		return;

	terminateSelector = theSelector;
	terminateObject = [theObject retain];
	
	if (theInfo)
		terminateInfo = theInfo;
	else
		terminateInfo = self;

	[terminateInfo retain];
	observing = YES;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(terminatedTaskNotification:)
						name:NSTaskDidTerminateNotification object:nil];
}

/* Callback for terminated NSTasks. */
- (void)terminatedTaskNotification:(NSNotification *)notification
{
	/* The [terminateObject perform....] below could actually end up deallocating self!
           This could (did, on my test setup) lead to the tool being deallocated, then reallocated (at the same address!)
           in the process of the perform, so that as this method finished it stepped all over the new instance.
           Solution: hang onto ourselves (so to speak) until we have finished the method.  At the very least this
                     will ensure the new instance gets allocated somewhere else. */
	[self retain];
	if ([notification object] == task && task)
	{
        	if (observing)
		{
			observing = FALSE;
			[[NSNotificationCenter defaultCenter] removeObserver:self];
		}
		if (terminateObject)
		{
			[terminateObject performSelector:terminateSelector withObject:terminateInfo];
			[terminateObject release];
			terminateObject = nil;
		}
		[terminateInfo release];
		terminateInfo = nil;

		/* We want at most one notification. */
		[task release];
		task = nil;
	}
	[self release];
}
 
@end
