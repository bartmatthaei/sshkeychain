#import "AgentController.h"

#include <unistd.h>

#import "Controller.h"
#import "PreferenceController.h"
#import "TunnelController.h"

#import "Libs/SSHTool.h"

#include "SSHKeychain_Prefix.pch"

/* This function resides in Controller.m. */
extern NSString *local(NSString *theString);
extern int sleep_timestamp;

extern TunnelController *tunnelController;

AgentController *agentController;

@implementation AgentController

- (id)init
{
	if(!(self = [super init]))
	{
		return NULL;
	}

	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(applicationDidFinishLaunching:)
			name:@"NSApplicationDidFinishLaunchingNotification" object:NSApp];

	[[NSNotificationCenter defaultCenter] addObserver:self 
		selector:@selector(powerChange:) name:@"SKSleep" object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self 
		selector:@selector(powerChange:) name:@"SKWake" object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self 
		selector:@selector(appleKeychainNotification:) name:@"AppleKeychainLocked" object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(appleKeychainNotification:) name:@"AppleKeychainUnlocked" object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(applicationWillTerminate:)
		name:@"NSApplicationWillTerminateNotification" object:NSApp];

	[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(keychainChanged:) name:@"KeychainChanged" object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(keysOnAgentStatusChange:) name:@"AgentFilled" object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(keysOnAgentStatusChange:) name:@"AgentEmptied" object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(keysOnAgentStatusChange:) name:@"KeysOnAgentUnknown" object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(agentStatusChange:) name:@"AgentStarted" object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(agentStatusChange:) name:@"AgentStopped" object:nil];

	[NSThread detachNewThreadSelector:@selector(checkForScreenSaver:)
						toTarget:self withObject:self];

	allKeysOnAgentLock = [[NSLock alloc] init];

	agentController = self;

	return self;
}

- (void)dealloc
{
	[allKeysOnAgentLock dealloc];
	
	[super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSString *path = [[NSUserDefaults standardUserDefaults] stringForKey:socketPathString];

	NSString *agentPath = [[[NSUserDefaults standardUserDefaults] stringForKey:sshToolsPathString] stringByAppendingPathComponent:@"ssh-agent"];
		
	SecKeychainStatus status;
	SecKeychainGetStatus(NULL, &status);
	
	agent = [SSHAgent currentAgent];
	keychain = [SSHKeychain currentKeychain];

	[agent setSocketPath:path];

	if(![[NSFileManager defaultManager] isExecutableFileAtPath:agentPath])
	{
		[self warningPanelWithTitle:local(@"StartAgent") andMessage:local(@"AgentNotFound")];
		return;
	}

	if([self checkSocketPath:path])
	{
		if([agent start] == NO)
		{
			[self warningPanelWithTitle:local(@"StartAgent") andMessage:local(@"FailedToStartAgent")];
		}
	}

	else
	{
		[self warningPanelWithTitle:local(@"StartAgent") andMessage:local(@"FailedToStartAgentSocketpathInvalid")];
	}
	
	if((status & 1)
	&& (([[NSUserDefaults standardUserDefaults] integerForKey:followKeychainString] == 3)
	|| ([[NSUserDefaults standardUserDefaults] integerForKey:followKeychainString] == 4))
	&& (![keychain addingKeys]))
	{
		
		[allKeysOnAgentLock lock];
		
		if(allKeysOnAgent)
		{
			[allKeysOnAgentLock unlock];
			return;
		}
		
		[allKeysOnAgentLock unlock];
		
		SecKeychainGetStatus(NULL, &status);
		
		if((status & 1) && ([agent isRunning]))
		{
			[NSThread detachNewThreadSelector:@selector(addKeysToAgentWithoutInteractionInNewThread)
						 toTarget:self withObject:self];
		}
	}	

	[tunnelController launchAfterSleepTunnels];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	[agent stop];
}

- (void)powerChange:(NSNotification *)notification
{
	if([[notification name] isEqualToString:@"SKSleep"])
	{
		[tunnelController closeAllTunnels];
	}

	if([[notification name] isEqualToString:@"SKWake"])
	{
		[tunnelController closeAllTunnels];
		[tunnelController launchAfterSleepTunnels];
	}
	
	if(([[NSUserDefaults standardUserDefaults] integerForKey:onSleepString] == 1) && ([[agent keysOnAgent] count] > 0))
	{
		int minutes = [[NSUserDefaults standardUserDefaults] integerForKey:minutesOfSleepString];

		if([[notification name] isEqualToString:@"SKSleep"])
		{
			sleep_timestamp = time(NULL);	
		}

		else if(([[notification name] isEqualToString:@"SKWake"]) && (sleep_timestamp != 0))
		{
			/*
			 * Reduce the output of time() by minutes * 60 (to get the seconds),
			 * if it's more than the timestamp, remove all keys. 
			 */

			if((time(NULL) - (minutes * 60)) > sleep_timestamp)
			{
				[self removeKeysFromAgent:nil];
			}

			sleep_timestamp = 0;
		}
	}
}

- (void)appleKeychainNotification:(NSNotification *)notification
{
	SecKeychainStatus status;
	
	if(([[notification name] isEqualToString:@"AppleKeychainLocked"])
	&& (([[NSUserDefaults standardUserDefaults] integerForKey:followKeychainString] == 2)
	|| ([[NSUserDefaults standardUserDefaults] integerForKey:followKeychainString] == 4)))
	{
		if([[agent keysOnAgent] count] > 0)
		{
			[self removeKeysFromAgent:nil];
		}
	}

	else if(([[notification name] isEqualToString:@"AppleKeychainUnlocked"])
	&& (([[NSUserDefaults standardUserDefaults] integerForKey:followKeychainString] == 3)
	|| ([[NSUserDefaults standardUserDefaults] integerForKey:followKeychainString] == 4))
	&& (![keychain addingKeys]))
	{

		[allKeysOnAgentLock lock];

		if(allKeysOnAgent)
		{
			[allKeysOnAgentLock unlock];
			return;
		}

		[allKeysOnAgentLock unlock];

		SecKeychainGetStatus(NULL, &status);

		if((status & 1) && ([agent isRunning]))
		{
			[NSThread detachNewThreadSelector:@selector(addKeysToAgentWithoutInteractionInNewThread)
								toTarget:self withObject:self];
		}
	}
}

- (void)keychainChanged:(NSNotification *)notification
{
	if([keychain count] > 0)
	{
		[mainMenuAddKeysItem setEnabled:YES];
		[dockMenuAddKeysItem setEnabled:YES];
		[statusbarMenuAddKeysItem setEnabled:YES];
	}

	else
	{
		[mainMenuAddKeysItem setEnabled:NO];
		[dockMenuAddKeysItem setEnabled:NO];
		[statusbarMenuAddKeysItem setEnabled:NO];		
	}
}

- (void)keysOnAgentStatusChange:(NSNotification *)notification
{
	if([[notification name] isEqualToString:@"AgentEmptied"])
	{
		[self updateUI];

		[mainMenuRemoveKeysItem setEnabled:NO];
		[dockMenuRemoveKeysItem setEnabled:NO];
		[statusbarMenuRemoveKeysItem setEnabled:NO];

		[mainMenuAddKeysItem setEnabled:YES];
		[dockMenuAddKeysItem setEnabled:YES];
		[statusbarMenuAddKeysItem setEnabled:YES];

		[allKeysOnAgentLock lock];
		allKeysOnAgent = NO;
		[allKeysOnAgentLock unlock];
		
		[[Controller currentController] setStatus:NO];
	}

	else if([[notification name] isEqualToString:@"AgentFilled"])
	{
		[self updateUI];

		[mainMenuRemoveKeysItem setEnabled:YES];
		[dockMenuRemoveKeysItem setEnabled:YES];
		[statusbarMenuRemoveKeysItem setEnabled:YES];

		[mainMenuAddKeysItem setEnabled:NO];
		[dockMenuAddKeysItem setEnabled:NO];
		[statusbarMenuAddKeysItem setEnabled:NO];		

		[allKeysOnAgentLock lock];
		allKeysOnAgent = YES;
		[allKeysOnAgentLock unlock];
		
		[[Controller currentController] setStatus:YES];
	}

	else if([[notification name] isEqualToString:@"KeysOnAgentUnknown"])
	{
		[self updateUI];
		
		if([[agent keysOnAgent] count] > 0)
		{
			[mainMenuRemoveKeysItem setEnabled:YES];
			[dockMenuRemoveKeysItem setEnabled:YES];
			[statusbarMenuRemoveKeysItem setEnabled:YES];
			[[Controller currentController] setStatus:YES];
		} else {
			
			[mainMenuRemoveKeysItem setEnabled:NO];
			[dockMenuRemoveKeysItem setEnabled:NO];
			[statusbarMenuRemoveKeysItem setEnabled:NO];
			
			[[Controller currentController] setStatus:NO];
		}
	}
}

- (void)agentStatusChange:(NSNotification *)notification
{
	SecKeychainStatus status;

	if([[notification name] isEqualToString:@"AgentStarted"])
	{
		[self updateUI];

		[keychain setAgentSocketPath:[agent agentSocketPath]];
		
		[mainMenuAgentItem setTitle:local(@"StopAgent")];
		[dockMenuAgentItem setTitle:local(@"StopAgent")];
		[statusbarMenuAgentItem setTitle:local(@"StopAgent")];

		[mainMenuAddKeysItem setEnabled:YES];
		[dockMenuAddKeysItem setEnabled:YES];
		[statusbarMenuAddKeysItem setEnabled:YES];

		[mainMenuAddKeyItem setEnabled:YES];
		[dockMenuAddKeyItem setEnabled:YES];
		[statusbarMenuAddKeyItem setEnabled:YES];
		
		[[Controller currentController] setStatus:NO];

		SecKeychainGetStatus(NULL, &status);

		if((([[NSUserDefaults standardUserDefaults] integerForKey:followKeychainString] == 3)
			|| ([[NSUserDefaults standardUserDefaults] integerForKey:followKeychainString] == 4))
			&& (![keychain addingKeys]) && (status & 1) && ([agent isRunning]))
		{
			[NSThread detachNewThreadSelector:@selector(addKeysToAgentWithoutInteractionInNewThread)
				toTarget:self withObject:self];
		}

	}

	else if([[notification name] isEqualToString:@"AgentStopped"])
	{
		[self updateUI];

		[keychain setAgentSocketPath:@""];
		
		[mainMenuAgentItem setTitle:local(@"StartAgent")];
		[dockMenuAgentItem setTitle:local(@"StartAgent")];
		[statusbarMenuAgentItem setTitle:local(@"StartAgent")];

		[mainMenuRemoveKeysItem setEnabled:NO];
		[dockMenuRemoveKeysItem setEnabled:NO];
		[statusbarMenuRemoveKeysItem setEnabled:NO];

		[mainMenuAddKeysItem setEnabled:NO];
		[dockMenuAddKeysItem setEnabled:NO];
		[statusbarMenuAddKeysItem setEnabled:NO];

		[mainMenuAddKeyItem setEnabled:NO];
		[dockMenuAddKeyItem setEnabled:NO];
		[statusbarMenuAddKeyItem setEnabled:NO];
		
		[[Controller currentController] setStatus:NO];

		[allKeysOnAgentLock lock];
		allKeysOnAgent = NO;
		[allKeysOnAgentLock unlock];
	}
}

- (void)awakeFromNib
{
	[keyTable setDataSource:self];

	[[mainMenuRemoveKeysItem menu] setAutoenablesItems:NO];
	[[dockMenuRemoveKeysItem menu] setAutoenablesItems:NO];
	[[statusbarMenuRemoveKeysItem menu] setAutoenablesItems:NO];

	[[mainMenuAddKeysItem menu] setAutoenablesItems:NO];
	[[dockMenuAddKeysItem menu] setAutoenablesItems:NO];
	[[statusbarMenuAddKeysItem menu] setAutoenablesItems:NO];

	[[mainMenuAddKeyItem menu] setAutoenablesItems:NO];
	[[dockMenuAddKeyItem menu] setAutoenablesItems:NO];
	[[statusbarMenuAddKeyItem menu] setAutoenablesItems:NO];	

	[mainMenuAddKeysItem setEnabled:NO];
	[dockMenuAddKeysItem setEnabled:NO];
	[statusbarMenuAddKeysItem setEnabled:NO];
	
	[mainMenuRemoveKeysItem setEnabled:NO];
	[dockMenuRemoveKeysItem setEnabled:NO];
	[statusbarMenuRemoveKeysItem setEnabled:NO];

	[mainMenuAddKeyItem setEnabled:NO];
	[dockMenuAddKeyItem setEnabled:NO];
	[statusbarMenuAddKeyItem setEnabled:NO];
	
	if([keychain count] > 0)
	{
		[mainMenuAddKeysItem setEnabled:YES];
		[dockMenuAddKeysItem setEnabled:YES];
		[statusbarMenuAddKeysItem setEnabled:YES];
	}
}

- (IBAction)toggleAgent:(id)sender
{
	NSString *path;

	if([agent isRunning])
	{
		if([agent stop] == NO)
		{
			[self warningPanelWithTitle:local(@"StopAgent") andMessage:local(@"FailedToStopAgent")];
		}
	}

	else {
		path = [[NSUserDefaults standardUserDefaults] stringForKey:socketPathString];

		[agent setSocketPath:path];

		if([self checkSocketPath:path])
		{
			if([agent start] == NO)
			{
				[self warningPanelWithTitle:local(@"StartAgent") andMessage:local(@"FailedToStartAgent")];
			}
		}

		else
		{
			[self warningPanelWithTitle:local(@"StartAgent") andMessage:local(@"FailedToStartAgentSocketpathInvalid")];
		}
	}
}

- (IBAction)addKeysToAgent:(id)sender
{
	if([agent isRunning])
	{
		[NSThread detachNewThreadSelector:@selector(addKeysToAgentInNewThread)
							toTarget:self withObject:nil];
	}
	
	else
	{
		[self warningPanelWithTitle:local(@"AddKeysToAgent") andMessage:local(@"AgentNotRunning")];
	}
}

- (void)addKeysToAgentInNewThread
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	if([keychain addKeysToAgent] == NO)
	{

		[NSApp activateIgnoringOtherApps:YES];
		[self warningPanelWithTitle:local(@"AddAllKeysToAgent") andMessage:local(@"AddAllKeysToAgentFailed")
			       inMainThread:YES];
	}

	[pool release];
}

- (void)addKeysToAgentWithoutInteractionInNewThread
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	[keychain addKeysToAgentWithInteraction:NO];

	[pool release];
}

/* Add a temporary key to the agent. */
- (IBAction)addSingleKeyToAgent:(id)sender
{
	if([agent isRunning])
	{
		[NSThread detachNewThreadSelector:@selector(addSingleKeyToAgentInNewThread) 
							toTarget:self withObject:nil];
	}

	else
	{
		[self warningPanelWithTitle:local(@"AddSingleKeyToAgent") andMessage:local(@"AgentNotRunning")];
	}
}

- (void)addSingleKeyToAgentInNewThread
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	NSString *dir = [NSString stringWithString:@"~/.ssh/"];
	NSString *path;
	SSHKey *key;
	SSHTool *theTool;
	int returnCode;

	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setCanChooseDirectories:NO];

	[NSApp activateIgnoringOtherApps:YES];
	
	returnCode = [openPanel runModalForDirectory:[dir stringByExpandingTildeInPath] file:nil types:nil];

	if(returnCode == NSCancelButton)
	{
		return;
	}

	/* Get the path of the key we need to add. */
	path = [[openPanel filenames] objectAtIndex:0];

	/* This shouldn't happen. */
	if(!path)
	{
		return;
	}

	/* If the key isn't readable, warn the user. */
	if([[NSFileManager defaultManager] isReadableFileAtPath:path] == NO)
	{
		[self warningPanelWithTitle:local(@"InvalidKey") andMessage:local(@"ReadPermissionToKeyDenied")
			       inMainThread:YES];
		return;
	}

	else {
		key = [SSHKey keyWithPath:path];
		int type = [key type];

		/* If we can't get a decent type, warn the user. */
		if(type == 0)
		{
			[self warningPanelWithTitle:local(@"InvalidKey") andMessage:local(@"InvalidPrivateKey")
				       inMainThread:YES];
			return;
		}
	}

	if(!path)
	{
		[pool release];
		return;
	}

	theTool =  [SSHTool toolWithName:@"ssh-add"];
	[theTool setArgument:path];
	
        /* Set the SSH_ASKPASS + DISPLAY environment variables, so the tool can ask for a passphrase. */
	[theTool setEnvironmentVariable:@"SSH_ASKPASS" withValue:
		[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"PassphraseRequester"]];

	[theTool setEnvironmentVariable:@"DISPLAY" withValue:@":0"];
	[theTool setEnvironmentVariable:@"INTERACTION" withValue:@"1"];

	/* Set the SSH_AUTH_SOCK environment variable. */
	[theTool setEnvironmentVariable:@"SSH_AUTH_SOCK" withValue:[agent socketPath]];

	if([theTool launchAndWait] == NO)
	{
		[self warningPanelWithTitle:local(@"AddSingleKeyToAgent") andMessage:local(@"AddSingleKeyToAgentFailed")
			       inMainThread:YES];
	}

	[pool release];
}

- (IBAction)removeKeysFromAgent:(id)sender
{
	if([agent isRunning])
	{
		[NSThread detachNewThreadSelector:@selector(removeKeysFromAgentInNewThread)
									toTarget:self withObject:nil];
	}
}

- (void)removeKeysFromAgentInNewThread
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	if([keychain removeKeysFromAgent] == NO)
	{
		[self warningPanelWithTitle:local(@"RemoveAllKeysFromAgent")
			andMessage:local(@"RemoveAllKeysFromAgentFailed")
			       inMainThread:YES];
	}
	
	[pool release];
}

- (IBAction)showAgentStatusWindow:(id)sender
{	
	[self updateUI];
	[NSApp activateIgnoringOtherApps:YES];
	[agentStatusWindow makeKeyAndOrderFront:self];
}

- (void)updateUI
{
	[keyTable reloadData];

	if([agent isRunning])
	{
		[agentPID setIntValue:[agent pid]];
		[agentGlobalAuthSocket setStringValue:[agent socketPath]];
		[agentLocalAuthSocket setStringValue:[agent agentSocketPath]];
	}

	else
	{
		[agentPID setStringValue:@""];
		[agentGlobalAuthSocket setStringValue:@""];
		[agentLocalAuthSocket setStringValue:@""];
	}
}

- (int)numberOfRowsInTableView:(NSTableView *)theTable
{
	NSArray *keysOnAgent = [agent keysOnAgent];

	if(keysOnAgent)
	{
		return [keysOnAgent count];
	}

	return 0;
}

- (id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(int)nr
{
	NSArray *theArray = [agent keysOnAgent];
	
	if([theArray count] > 0)
	{
		if([[column identifier] isEqualToString:@"name"])
			return [[theArray objectAtIndex:nr] objectAtIndex:0];

		else if([[column identifier] isEqualToString:@"fingerprint"])
			return [[theArray objectAtIndex:nr] objectAtIndex:1];

		else if([[column identifier] isEqualToString:@"type"])
			return [[theArray objectAtIndex:nr] objectAtIndex:2];
	}

	return NULL;
}

/* Wrapper for warningPanelWithTitle: andMessage: inMainThread: */
- (void)warningPanelWithTitle:(NSString *)title andMessage:(NSString *)message
{
	[self warningPanelWithTitle:title andMessage:message inMainThread:NO];
}

/* This method either displays the warning directly, or asks the main thread to display it.*/
- (void)warningPanelWithTitle:(NSString *)title andMessage:(NSString *)message inMainThread:(BOOL)thread
{
	if(thread == YES) {
		id UI = [NSConnection rootProxyForConnectionWithRegisteredName:@"SSHKeychain" host:NULL];

		if(UI == NULL) {
			NSLog(@"Can't connect to UI to post warning");
		}

		[UI setProtocolForProxy:@protocol(UI)];
		[UI warningPanelWithTitle:title andMessage:message];
		
	} else {
		
		[NSApp activateIgnoringOtherApps:YES];
		NSRunAlertPanel(title, message, nil, nil, nil);
	}
}

- (void)checkForScreenSaver:(id)object
{
	NSAutoreleasePool *pool;
	NSTask *task;
	NSPipe *thePipe;
	NSString *theOutput;
	
	while(1)
	{
		pool = [[NSAutoreleasePool alloc] init];
		
		if(([[NSUserDefaults standardUserDefaults] integerForKey:onScreensaverString] > 1)
		&& ([[NSFileManager defaultManager] isExecutableFileAtPath:@"/bin/ps"]))
		{
			task = [[[NSTask alloc] init] autorelease];
			thePipe = [[[NSPipe alloc] init] autorelease];
			
			[task setLaunchPath:@"/bin/ps"];
			[task setArguments:[NSArray arrayWithObject:@"wxo command"]];
        		[task setStandardOutput:thePipe];

			[task launch];
			[task waitUntilExit];

			/* Put the data from thePipe to theOutput. */
			theOutput = [[[NSString alloc] initWithData:[[thePipe fileHandleForReading] readDataToEndOfFile] encoding:NSASCIIStringEncoding] autorelease];
	
			if(strstr([theOutput cString], "ScreenSaverEngine.app") != NULL)
			{
				if((([[NSUserDefaults standardUserDefaults] integerForKey:onScreensaverString] == 2)
				|| ([[NSUserDefaults standardUserDefaults] integerForKey:onScreensaverString] == 4))
				&& ([[agent keysOnAgent] count] > 0))
				{
					[object removeKeysFromAgent:nil];
				}

				if(([[NSUserDefaults standardUserDefaults] integerForKey:onScreensaverString] == 3)
				|| ([[NSUserDefaults standardUserDefaults] integerForKey:onScreensaverString] == 4))
				{
					SecKeychainLockAll();
				}

			}
		}
		
		sleep(30);
		[pool release];
	}
}

- (BOOL)checkSocketPath:(NSString *)path
{
	NSString *dir, *errorString;
	NSDictionary *attributes;
	BOOL isDirectory;

	if(path == NULL)
	{
			[self warningPanelWithTitle:local(@"AgentNotStarted") andMessage:local(@"InternalInconsistency")];
	}
	
	dir = [path stringByDeletingLastPathComponent];
	
	attributes = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0700]
						forKey:@"NSFilePosixPermissions"];

	if(([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]) && (isDirectory))
	{
			errorString = [NSString stringWithFormat:@"%@ (%@). %@", local(@"SocketpathDirectory"), path, local(@"PleaseChangeSocketpath")];

			[self warningPanelWithTitle:local(@"AgentNotStarted") andMessage:errorString];
			return NO;
	}

	else if(([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory]) && (!isDirectory))
	{
		if(access([dir cString], W_OK) != 0)
		{
			errorString = [NSString stringWithFormat:@"%@ (%@). %@.", local(@"Can'tWriteSocketInDirectory"), dir, local(@"PleaseCheckPermissions")];

			[self warningPanelWithTitle:local(@"AgentNotStarted") andMessage:errorString];
			return NO;
		}
	}

	else if(![[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDirectory])
	{
		if(![[NSFileManager defaultManager] createDirectoryAtPath:dir attributes:attributes])
		{
			errorString = [NSString stringWithFormat:@"%@ (%@). %@", local(@"Couldn'tCreateSocketDirectory"), dir, local(@"PleaseCreateItManually")];

			[self warningPanelWithTitle:local(@"AgentNotStarted") andMessage:errorString];
			return NO;
		}

		return YES;
	}
	
	else if(isDirectory == NO)
	{
		[[NSFileManager defaultManager] removeFileAtPath:dir handler:nil];
		if(![[NSFileManager defaultManager] createDirectoryAtPath:dir attributes:attributes])
		{
			errorString = [NSString stringWithFormat:@"%@ (%@). %@", local(@"Couldn'tCreateSocketDirectory"), dir, local(@"PleaseCreateItManually")];

			[self warningPanelWithTitle:local(@"AgentNotStarted") andMessage:errorString];
			return NO;
		}

		return YES;
	}

	return YES;
}

@end
