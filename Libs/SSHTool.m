/* $Id: SSHTool.m,v 1.13 2004/06/23 08:12:21 bart Exp $ */

#import "SSHTool.h"

#import "PreferenceController.h"

#include <unistd.h>

@implementation SSHTool

/* Construct a SSHTool object for the required tool. */
+ (id)toolWithName:(NSString *)toolname
{
	SSHTool *tool = [[[self alloc] init] autorelease];
	
	[tool setPath:[[[NSUserDefaults standardUserDefaults] 
			stringForKey:sshToolsPathString] 
			stringByAppendingPathComponent:toolname]];
	
	return tool;
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
	if((self = [super init]) == NULL)
	{
		return NULL;
	}

	task = [[NSTask alloc] init];
	[task setStandardInput:[NSFileHandle fileHandleWithNullDevice]];

	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSTaskDidTerminateNotification object:nil];
	
	[task release];
	
	[super dealloc];
}

/* Set the path. */
- (void)setPath:(NSString *)path
{
	toolPath = [NSString stringWithString:path];
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
	NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[task environment]];

	if((variable) && (value))
	{
		[env setObject:value forKey:variable];
		[task setEnvironment:env];
	}
}

/* Launch and return the stdout as an NSString. */
- (NSString *)launchForStandardOutput
{
	NSPipe *thePipe = [[[NSPipe alloc] init] autorelease];
	NSString *theOutput;

	[task setStandardOutput:thePipe];

	if([self launchAndWait] == NO)
	{
		return NULL;
	}

	/* Retrieve the stdout as a NSPipe. */
	thePipe = [task standardOutput];

	/* Put the data from thePipe to theOutput. */
	theOutput = [[[NSString alloc] initWithData:[[thePipe fileHandleForReading] readDataToEndOfFile] encoding:NSASCIIStringEncoding] autorelease];

	return theOutput;
}

/* Launch and wait until exit, returning a BOOL to report success or failure. */
- (BOOL)launchAndWait
{
	if(![self launch])
	{
		return NO;
	}
	
	[task waitUntilExit];
	
	if([task terminationStatus] == 0)
	{
		return YES;
	}
	
	else
	{
		return NO;
	}
}

/* Launch. */
- (BOOL)launch
{
	/* Let's see if the path is accessible. */
	if(![[NSFileManager defaultManager] isExecutableFileAtPath:toolPath])
	{
		return NO;
	}

	/* Set the launchpath to the path instance variable. */
	[task setLaunchPath:toolPath];

	if([task launch]) {
		return YES;
	}
	
	return NO;
}

/* Terminate. */
- (void)terminate
{
	[task terminate];
}

/* Handle terminate notifications. */
- (void)handleTerminateWithSelector:(SEL)theSelector toObject:(id)theObject withInfo:(id)theInfo
{
	if((!theSelector) || (!theObject)) 
	{
		return;
	}
	
	terminateSelector = theSelector;
	terminateObject = theObject;
	
	if(theInfo)
	{
		terminateInfo = theInfo;
	}
	
	else
	{
		terminateInfo = self;
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(terminatedTaskNotification:)
						name:NSTaskDidTerminateNotification object:nil];
}

/* Callback for terminated NSTasks. */
- (void)terminatedTaskNotification:(NSNotification *)notification
{
	if([notification object] == task)
	{
		[terminateObject performSelector:terminateSelector withObject:terminateInfo];
	}
}
 
@end
