#import "TunnelController.h"

#import "Controller.h"
#import "PreferenceController.h"
#import "Libs/SSHTunnel.h"
#import "Utilities.h"
#import "NSMenu_Additions.h"

#ifndef NSAppKitVersionNumber10_3
#define NSAppKitVersionNumber10_3 743
#endif

#include "SSHKeychain_Prefix.pch"

/* This function resides in Controller.m. */
extern NSString *local(NSString *theString);

TunnelController *sharedTunnelController;

@implementation TunnelController

- (id)init
{		
	if(self = [super init])
	{
		[[NSNotificationCenter defaultCenter] addObserver:self
						selector:@selector(applicationDidFinishLaunching:)
						name:@"NSApplicationDidFinishLaunchingNotification" object:NSApp];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
							 selector:@selector(applicationWillTerminate:)
								 name:@"NSApplicationWillTerminateNotification" object:NSApp];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
							 selector:@selector(agentFilledNotification:) name:@"AgentFilled" object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
							 selector:@selector(agentEmptiedNotification:) name:@"AgentEmptied" object:nil];

		sharedTunnelController = self;

		notificationQueue  = [[NSMutableArray alloc] init];
		notificationLock   = [[NSLock alloc] init];
		notificationThread = [[NSThread currentThread] retain];
		notificationPort   = [[NSMachPort alloc] init];

		[notificationPort setDelegate:self];

		[[NSRunLoop currentRunLoop] addPort:notificationPort forMode:(NSString *)kCFRunLoopCommonModes];
	}
	
	return self;
}

+ (TunnelController *)sharedController
{
	if(!sharedTunnelController) {
		return [[TunnelController alloc] init];
	}

	return sharedTunnelController;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	tunnels = [[NSMutableArray alloc] init];
	
	[self sync];

	[self setToolTipForActiveTunnels];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	[self closeAllTunnels];
}

- (void)sync
{
	NSArray *newTunnels;
	NSMutableDictionary *dict;
	int i;
	BOOL match;
	
	if(!tunnels) { return; }
	
	[[NSUserDefaults standardUserDefaults] synchronize];
	newTunnels = [[NSUserDefaults standardUserDefaults] arrayForKey:TunnelsString];
	
	// Because we're adding UUIDs, we should give them to all tunnels that don't yet have them
	BOOL setUUID = NO;
	NSEnumerator *e =  [newTunnels objectEnumerator];
	NSDictionary *aTunnel;
	NSMutableArray *modifiedTunnels = [NSMutableArray array];
	while (aTunnel = [e nextObject]) {
		if ([aTunnel objectForKey:@"TunnelUUID"] == nil)
		{
			NSMutableDictionary *modifiedTunnel = [NSMutableDictionary dictionaryWithDictionary:aTunnel];
			[modifiedTunnel setObject:CreateUUID() forKey:@"TunnelUUID"];
			[modifiedTunnels addObject:modifiedTunnel];
			setUUID = YES;
		} else {
			[modifiedTunnels addObject:aTunnel];
		}
	}
	if (setUUID) {
		newTunnels = [NSArray arrayWithArray:modifiedTunnels];
		[[NSUserDefaults standardUserDefaults] setObject:newTunnels forKey:TunnelsString];
	}
	
	e = [newTunnels objectEnumerator];
	while (aTunnel = [e nextObject]) {
		match = NO;
		
		for(i=0; i < [tunnels count]; i++)
		{
			NSDictionary *oldTunnel = [tunnels objectAtIndex:i];
			if([[aTunnel objectForKey:@"TunnelUUID"] isEqualToString:
				[oldTunnel objectForKey:@"TunnelUUID"]])
			{
				dict = [NSMutableDictionary dictionaryWithDictionary:aTunnel];

				if([oldTunnel objectForKey:@"TunnelObject"]) 
				{
					[dict setObject:[oldTunnel objectForKey:@"TunnelObject"] forKey:@"TunnelObject"];
				}

				[tunnels replaceObjectAtIndex:i withObject:dict];

				match = YES;
			}
		}
		
		if(!match)
		{
			dict = [NSMutableDictionary dictionaryWithDictionary:aTunnel];
			
			id <NSMenuItem> mItem;
			mItem = [mainMenuTunnelsItem addItemWithTitle:[dict objectForKey:@"TunnelName"]
												   action:@selector(toggleTunnel:)
											keyEquivalent:@""];
			[mItem setTarget:self];
			[mItem setRepresentedObject:[dict objectForKey:@"TunnelUUID"]];
			
			mItem = [dockMenuTunnelsItem addItemWithTitle:[dict objectForKey:@"TunnelName"]
												   action:@selector(toggleTunnel:)
											keyEquivalent:@""];
			[mItem setTarget:self];
			[mItem setRepresentedObject:[dict objectForKey:@"TunnelUUID"]];
			
			mItem = [statusbarMenuTunnelsItem addItemWithTitle:[dict objectForKey:@"TunnelName"]
														action:@selector(toggleTunnel:) keyEquivalent:@""];
			[mItem setTarget:self];
			[mItem setRepresentedObject:[dict objectForKey:@"TunnelUUID"]];
			
			[tunnels addObject:[NSMutableDictionary dictionaryWithDictionary:dict]];
		}
	}
}

- (void)changeTunnel:(NSString *)uuid setName:(NSString *)newName
{
	if(!tunnels) { return; }
	
	NSEnumerator *e = [tunnels objectEnumerator];
	NSMutableDictionary *aTunnel;
	while (aTunnel = [e nextObject])
	{
		if([[aTunnel objectForKey:@"TunnelUUID"] isEqualToString:uuid])
		{
			[aTunnel setObject:newName forKey:@"TunnelName"];
			
			[[mainMenuTunnelsItem itemWithRepresentation:uuid] setTitle:newName];
			[[statusbarMenuTunnelsItem itemWithRepresentation:uuid] setTitle:newName];
			[[dockMenuTunnelsItem itemWithRepresentation:uuid] setTitle:newName];
			
			return;
		}
	}
}

- (void)setToolTipForActiveTunnels
{
	Controller *controller = [Controller sharedController];
	int active = 0;
	
	if(!tunnels) { 
		[controller setToolTip:@""];
		return; 
	}
	
	NSEnumerator *e = [tunnels objectEnumerator];
	NSDictionary *aTunnel;
	while (aTunnel = [e nextObject])
	{
		if([aTunnel objectForKey:@"TunnelObject"])
		{
			active++;
		}
	}
	
	if(!active) {
		[controller setToolTip:local(@"NoActiveTunnels")];
	} else if(active == 1) {
		[controller setToolTip:[NSString stringWithFormat:@"1 %@", local(@"ActiveTunnel")]];
	} else {
		[controller setToolTip:[NSString stringWithFormat:@"%d %@", active, local(@"ActiveTunnels")]];
	}		
}

- (void)removeTunnelWithUUID:(NSString *)uuid
{
	SSHTunnel *tunnel;
	
	if(!tunnels) { return; }
	
	NSEnumerator *e = [tunnels objectEnumerator];
	NSDictionary *aTunnel;
	while (aTunnel = [e nextObject])
	{
		if([[aTunnel objectForKey:@"TunnelUUID"] isEqualToString:uuid])
		{
			tunnel = [aTunnel objectForKey:@"TunnelObject"];
			
			if (tunnel)
			{
				[tunnel closeTunnel];
			}
			
			[tunnels removeObjectIdenticalTo:aTunnel];

			[mainMenuTunnelsItem removeItem:[mainMenuTunnelsItem itemWithRepresentation:uuid]];
			[dockMenuTunnelsItem removeItem:[dockMenuTunnelsItem itemWithRepresentation:uuid]];
			[statusbarMenuTunnelsItem removeItem:[statusbarMenuTunnelsItem itemWithRepresentation:uuid]];
		}
	}
}

- (void)closeAllTunnels
{	
	if(!tunnels) { return; }
	
	NSEnumerator *e = [tunnels objectEnumerator];
	NSMutableDictionary *aTunnel;
	while (aTunnel = [e nextObject]) 
	{
		if([aTunnel objectForKey:@"TunnelObject"]) 
		{
			SSHTunnel *tunnel = [aTunnel objectForKey:@"TunnelObject"];
			NSString *uuid = [aTunnel objectForKey:@"TunnelUUID"];
			
			[tunnel closeTunnel];
			[aTunnel removeObjectForKey:@"TunnelObject"];
			
			[[mainMenuTunnelsItem itemWithRepresentation:uuid] setState:NO];
			[[statusbarMenuTunnelsItem itemWithRepresentation:uuid] setState:NO];
			[[dockMenuTunnelsItem itemWithRepresentation:uuid] setState:NO];
		}
	}
	
	[self setToolTipForActiveTunnels];
}

- (void)launchAfterSleepTunnels
{
	SSHTunnel *tunnel;
	NSString *uuid;
	
	if(!tunnels) { return; }
	
	NSEnumerator *e = [tunnels objectEnumerator];
	NSMutableDictionary *aTunnel;
	while (aTunnel = [e nextObject])
	{
		if([aTunnel objectForKey:@"LaunchAfterSleep"]) 
		{
			/* First kill the tunnel, if it's still open. */
			if([aTunnel objectForKey:@"TunnelObject"]) 
			{
				tunnel = [aTunnel objectForKey:@"TunnelObject"];
				uuid = [aTunnel objectForKey:@"TunnelUUID"];
			
				[tunnel closeTunnel];
				[aTunnel removeObjectForKey:@"TunnelObject"];
			
				[[mainMenuTunnelsItem itemWithRepresentation:uuid] setState:NO];
				[[statusbarMenuTunnelsItem itemWithRepresentation:uuid] setState:NO];
				[[dockMenuTunnelsItem itemWithRepresentation:uuid] setState:NO];
			}

			[self openTunnelWithDict:aTunnel];
		}
	}
	
	[self setToolTipForActiveTunnels];
}

- (void)toggleTunnel:(id)sender
{
	NSMutableDictionary *dict;
	SSHTunnel *tunnel;
	
	dict = nil;
	
	if(!tunnels) { return; }
	
	NSEnumerator *e = [tunnels objectEnumerator];
	NSMutableDictionary *aTunnel;
	while (aTunnel = [e nextObject])
	{
		if([[aTunnel objectForKey:@"TunnelUUID"] isEqualToString:[sender representedObject]]) 
		{
			dict = aTunnel;
			break;
		}
	}
	
	if(!dict) { return; }
	
	if([dict objectForKey:@"TunnelObject"]) 
	{
		
		tunnel = [dict objectForKey:@"TunnelObject"];

		[tunnel closeTunnel];
		
		[dict removeObjectForKey:@"TunnelObject"];
		
		[sender setState:NO];
	} 
	
	else 
	{
		[self openTunnelWithDict:dict];
	}
	
	[self setToolTipForActiveTunnels];
}

/* Handle closed tunnels. */
- (void)handleClosedTunnels:(NSString *)contextInfo
{
	int last_terminated;
	NSString *output;
	BOOL fails_exceeded = NO;
		
	if(!contextInfo)
	{
		return;
	}

	[[mainMenuTunnelsItem itemWithRepresentation:contextInfo] setState:NO];
	[[statusbarMenuTunnelsItem itemWithRepresentation:contextInfo] setState:NO];
	[[dockMenuTunnelsItem itemWithRepresentation:contextInfo] setState:NO];
	
	if(!tunnels)
	{
		return;
	}
	
	NSEnumerator *e = [tunnels objectEnumerator];
	NSMutableDictionary *aTunnel;
	while (aTunnel = [e nextObject])
	{
		if([[aTunnel objectForKey:@"TunnelUUID"] isEqualToString:contextInfo]) 
		{
			SSHTunnel *tunnel = [aTunnel objectForKey:@"TunnelObject"];
			
			if(tunnel) 
			{
				last_terminated = 0;
				fails_exceeded = NO;
				
				output = [tunnel getOutput];
				
				[aTunnel removeObjectForKey:@"TunnelObject"];

				if([aTunnel objectForKey:@"LastTerminated"]) 
				{
					last_terminated = [[aTunnel objectForKey:@"LastTerminated"] intValue];
				}

				if((last_terminated) && ((time(nil) - last_terminated) < 300)) 
				{
					fails_exceeded = YES;
					[aTunnel removeObjectForKey:@"LastTerminated"];
				} 
				
				else if((allKeysOnAgent) && ([output length] < 1))
				{
					[aTunnel setObject:[NSNumber numberWithInt:time(nil)] forKey:@"LastTerminated"];
					[self openTunnelWithDict:aTunnel];
				}

				if((fails_exceeded) && ([output length] > 0)) 
				{
					[self warningPanelWithTitle:local(@"TunnelTerminated") 
							 andMessage:[NSString stringWithFormat:@"(%@) %@",
								 [aTunnel objectForKey:@"TunnelName"],
								 local(@"TunnelTerminatedAndCouldNotBeRestarted")]];
				}
				
				else if((!fails_exceeded) && (!allKeysOnAgent) && ([output length] < 1)) {
					[self warningPanelWithTitle:local(@"TunnelTerminated") 
							 andMessage:[NSString stringWithFormat:@"(%@) %@",
								 [aTunnel objectForKey:@"TunnelName"],
								 local(@"TunnelTerminatedAndCouldNotBeRestarted")]];
				}

				else if([output isEqualToString:@"tunnel failed\n"]) 
				{
					[self warningPanelWithTitle:local(@"TunnelForwardingFailed") 
							 andMessage:[NSString stringWithFormat:@"(%@) %@",
								 [aTunnel objectForKey:@"TunnelName"],
								 local(@"ForwardingFailedDuringInitialization")]];
				} 
				
				else if([output length] > 0) 
				{
					[self warningPanelWithTitle:local(@"TunnelSetupFailed")
							 andMessage:[NSString stringWithFormat:@"(%@) Error:\n%@", 
								 [aTunnel objectForKey:@"TunnelName"],
								 output]];
				}
				
				else if(fails_exceeded)
				{
					[self warningPanelWithTitle:local(@"TunnelTerminated")
							 andMessage:[NSString stringWithFormat:@"(%@) %@",
								 [aTunnel objectForKey:@"TunnelName"],
								 local(@"TunnelUnexpectedlyTerminated")]];
				}
			}
		}
	}
	
	[self setToolTipForActiveTunnels];
}

/* Handle Apple keychain unlocks. */
- (void)agentFilledNotification:(NSNotification *)notification
{
	/* Forward the notification to the correct thread. */
	if([NSThread currentThread] != notificationThread) 
	{
		[notificationLock lock];
		[notificationQueue addObject:notification];
		[notificationLock unlock];

		[notificationPort sendBeforeDate:[NSDate date] components:nil from:nil reserved:0];

		return;
	}
		
	allKeysOnAgent = YES;
	
	if(!tunnels) { return; }
	
	NSEnumerator *e = [tunnels objectEnumerator];
	NSMutableDictionary *aTunnel;
	while (aTunnel = [e nextObject])
	{
		if(![aTunnel objectForKey:@"TunnelObject"] && [aTunnel objectForKey:@"LaunchOnAgentFilled"]) 
		{
			[self openTunnelWithDict:aTunnel];
		}
	}
}

/* Handle Apple keychain unlocks. */
- (void)agentEmptiedNotification:(NSNotification *)notification
{
	allKeysOnAgent = NO;
}

/* Wrapper to open the tunnel. */
- (void)openTunnelWithDict:(NSMutableDictionary *)dict
{
	int i;
	SSHTunnel *tunnel = [[SSHTunnel alloc] init];
	
	[tunnel setTunnelHost:[dict objectForKey:@"TunnelHostname"]
			withPort:[[dict objectForKey:@"TunnelPort"] intValue]
			andUser:[dict objectForKey:@"TunnelUser"]];

	if([dict objectForKey:@"Compression"])
	{
		[tunnel setCompression:YES];
	}
	
	if([dict objectForKey:@"RemoteAccess"])
	{
		[tunnel setRemoteAccess:YES];
	}

	if([dict objectForKey:@"LocalPortForwards"]) 
	{
		for(i=0; i < [[dict objectForKey:@"LocalPortForwards"] count]; i++)
		{
			[tunnel addLocalPortForwardWithPort:[[[[dict objectForKey:@"LocalPortForwards"] objectAtIndex:i] objectForKey:@"LocalPort"] intValue]
						remoteHost:[[[dict objectForKey:@"LocalPortForwards"] objectAtIndex:i] objectForKey:@"RemoteHost"]
						remotePort:[[[[dict objectForKey:@"LocalPortForwards"] objectAtIndex:i] objectForKey:@"RemotePort"] intValue]
			];
		}
	}
							
	if([dict objectForKey:@"RemotePortForwards"]) 
	{
		for(i=0; i < [[dict objectForKey:@"RemotePortForwards"] count]; i++)
		{
			[tunnel addRemotePortForwardWithPort:[[[[dict objectForKey:@"RemotePortForwards"] objectAtIndex:i] objectForKey:@"RemotePort"] intValue]
						localHost:[[[dict objectForKey:@"RemotePortForwards"] objectAtIndex:i] objectForKey:@"LocalHost"]
						localPort:[[[[dict objectForKey:@"RemotePortForwards"] objectAtIndex:i] objectForKey:@"LocalPort"] intValue]
			];
		}
	}
	
	if([dict objectForKey:@"DynamicPortForwards"]) 
	{
		for(i=0; i < [[dict objectForKey:@"DynamicPortForwards"] count]; i++)
		{
			[tunnel addDynamicPortForwardWithPort:[[[[dict objectForKey:@"DynamicPortForwards"] objectAtIndex:i] objectForKey:@"LocalPort"] intValue]];
		}
	}
	
	[tunnel handleClosedWithSelector:@selector(handleClosedTunnels:) toObject:self 
				withInfo:[dict objectForKey:@"TunnelUUID"]];
	
	if([tunnel openTunnel]) 
	{
		[dict setObject:tunnel forKey:@"TunnelObject"];
		/* Now that the dictionary has it, we can let it go, see below. */
		
		NSString *uuid = [dict objectForKey:@"TunnelUUID"];
		[[mainMenuTunnelsItem itemWithRepresentation:uuid] setState:YES];
		[[statusbarMenuTunnelsItem itemWithRepresentation:uuid] setState:YES];
		[[dockMenuTunnelsItem itemWithRepresentation:uuid] setState:YES];
		
		[self setToolTipForActiveTunnels];
	}
	/* Either the dictionary has it, or it didn't work and we don't want it. */
	[tunnel release];

}

/* This method displays a warning. */
- (void)warningPanelWithTitle:(NSString *)title andMessage:(NSString *)message
{
	/* Dictionary for the panel. */
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	
	[dict setObject:title forKey:(NSString *)kCFUserNotificationAlertHeaderKey];
	[dict setObject:message forKey:(NSString *)kCFUserNotificationAlertMessageKey];
	
	CFUserNotificationCreate(nil, 30, CFUserNotificationSecureTextField(0), nil, (CFDictionaryRef)dict);
}

/* Handle the notification queue. */
- (void)handleMachMessage:(void *)msg 
{
 
	[notificationLock lock];
 
	while([notificationQueue count]) {
		NSNotification *notification = [[notificationQueue objectAtIndex:0] retain];
		[notificationQueue removeObjectAtIndex:0];
		[notificationLock unlock];
		[self agentFilledNotification:notification];
		[notification release];
		[notificationLock lock];
	};
 
 
	[notificationLock unlock];
}
 
@end
