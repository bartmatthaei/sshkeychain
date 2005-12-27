#import "UpdateController.h"

#include "SSHKeychain_Prefix.pch"

UpdateController *sharedUpdateController;

/* This function resides in Controller.m. */
extern NSString *local(NSString *theString);

@implementation UpdateController

- (id)init
{
	if(!(self = [super init]))
	{
		return nil;
	}

	sharedUpdateController = self;

	return self;
}

+ (UpdateController *)sharedController
{
	if(!sharedUpdateController)
	{
		return [[UpdateController alloc] init];
	}

	return sharedUpdateController;
}

- (void)checkForUpdatesWithWarnings:(BOOL)warnings
{
	[NSThread detachNewThreadSelector:@selector(_checkForUpdatesWithWarnings:) toTarget:self withObject:[NSNumber numberWithBool:warnings]];
}

- (void)_checkForUpdatesWithWarnings:(NSNumber *)warnings
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSString *versionPath = [[NSBundle mainBundle] pathForResource:@"version" ofType:@"plist"];
	NSDictionary *versionDict = [NSDictionary dictionaryWithContentsOfFile:versionPath];
	NSString *remoteVersionURL = [versionDict objectForKey:@"RemoteVersionURL"];
	NSDictionary *remoteVersionInfo;

	remoteVersionInfo = [NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:remoteVersionURL]];

	NSMethodSignature *methodSig = [self methodSignatureForSelector:@selector(_processVersionInfo:withWarnings:)];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSig];
	[invocation setSelector:@selector(_processVersionInfo:withWarnings:)];
	[invocation setArgument:&remoteVersionInfo atIndex:2];
	[invocation setArgument:&warnings atIndex:3];
	[invocation retainArguments];
	[invocation performSelectorOnMainThread:@selector(invokeWithTarget:) withObject:self waitUntilDone:NO];
	
	[pool release];
}

- (void)_processVersionInfo:(NSDictionary *)remoteVersionInfo withWarnings:(NSNumber *)warnings
{
	NSString *latestVersion, *currentVersion;
	NSURL *downloadURL, *changesURL;
	int r;
	
	if(!remoteVersionInfo)
	{
		if([warnings boolValue] == YES) 
		{
			[self warningPanelWithTitle:local(@"CheckForUpdates")
				 andMessage:local(@"FailedToRetrieveXMLVersionInfo")];
		}
		return;
	}

	latestVersion = [remoteVersionInfo objectForKey:@"version"];
	downloadURL = [NSURL URLWithString:[remoteVersionInfo objectForKey:@"downloadURL"]];
	changesURL = [NSURL URLWithString:[remoteVersionInfo objectForKey:@"changesURL"]];

	currentVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];

	if(currentVersion == nil)
	{
		if([warnings boolValue] == YES)
		{
			[self warningPanelWithTitle:local(@"CheckForUpdates")
					 andMessage:local(@"Can'tFigureOutOwnVersion")];
		}
	}

	else if ([latestVersion compare:currentVersion] == NSOrderedDescending)
	{
		if((downloadURL) && (changesURL))
		{
			[NSApp requestUserAttention:NSCriticalRequest];
			[NSApp activateIgnoringOtherApps:YES];
			r = NSRunAlertPanel(local(@"NewVersion"), local(@"NewVersionAvailable"), local(@"Download"), local(@"Cancel"), local(@"Changes"));

			if(r == NSAlertDefaultReturn)
			{
				[[NSWorkspace sharedWorkspace] openURL:downloadURL];
			}

			else if(r == NSAlertOtherReturn)
			{
				[[NSWorkspace sharedWorkspace] openURL:changesURL];
			}
		}

		else
		{
			[self warningPanelWithTitle:local(@"NewVersion")
				andMessage:local(@"NewVersionAvailable")];
		}
     	}

	else if([warnings boolValue] == YES)
	{
		[self warningPanelWithTitle:local(@"NewVersion") andMessage:local(@"NoNewVersion")];
	}

	return;
}

- (void)warningPanelWithTitle:(NSString *)title andMessage:(NSString *)message
{
	[NSApp activateIgnoringOtherApps:YES];
	NSRunAlertPanel(title, message, nil, nil, nil);
}

@end
