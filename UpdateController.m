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
	NSString *latestVersion, *currentVersion;
	NSDictionary *remoteVersionInfo;
	NSURL *downloadURL, *changesURL;
	int r;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	remoteVersionInfo = [NSDictionary dictionaryWithContentsOfURL:[NSURL URLWithString:remoteVersionURL]];

	if(!remoteVersionInfo)
	{
		if([warnings boolValue] == YES) 
		{
			[self warningPanelWithTitle:local(@"CheckForUpdates")
				 andMessage:local(@"FailedToRetrieveXMLVersionInfo")];
		}

		[pool release];
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

	else if(strcmp([latestVersion cString], [currentVersion cString]) > 0)
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

	[pool release];

	return;
}

- (void)warningPanelWithTitle:(NSString *)title andMessage:(NSString *)message
{
	[NSApp activateIgnoringOtherApps:YES];
	NSRunAlertPanel(title, message, nil, nil, nil);
}

@end
