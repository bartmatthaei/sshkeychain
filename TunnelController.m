#import "TunnelController.h"

#import "Controller.h"
#import "PreferenceController.h"
#import "Libs/SSHTunnel.h"

#include "SSHKeychain_Prefix.pch"

/* This function resides in Controller.m. */
extern NSString *local(NSString *theString);

TunnelController *tunnelController;

@implementation TunnelController

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
						 selector:@selector(applicationWillTerminate:)
						     name:@"NSApplicationWillTerminateNotification" object:NSApp];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(agentFilledNotification:) name:@"AgentFilled" object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
						 selector:@selector(agentEmptiedNotification:) name:@"AgentEmptied" object:nil];

	tunnelController = self;

	notificationQueue  = [[NSMutableArray alloc] init];
	notificationLock   = [[NSLock alloc] init];
	notificationThread = [[NSThread currentThread] retain];
	notificationPort   = [[NSMachPort alloc] init];

	[notificationPort setDelegate:self];

	[[NSRunLoop currentRunLoop] addPort:notificationPort forMode:(NSString *)kCFRunLoopCommonModes];
	
	return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	tunnels = [[[[NSMutableArray alloc] init] autorelease] retain];
	
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
	int i, j;
	BOOL match;
	
	if(!tunnels) { return; }
	
	newTunnels = [NSArray arrayWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:tunnelsString]];

	for(i=0; i < [newTunnels count]; i++) 
	{
		match = NO;
		
		for(j=0; j < [tunnels count]; j++)
		{
			if([[[newTunnels objectAtIndex:i] objectForKey:@"TunnelName"] isEqualToString:
				[[tunnels objectAtIndex:j] objectForKey:@"TunnelName"]])
			{
				dict = [NSMutableDictionary dictionaryWithDictionary:[newTunnels objectAtIndex:i]];

				if([[tunnels objectAtIndex:j] objectForKey:@"TunnelObject"]) 
				{
					[dict setObject:[[tunnels objectAtIndex:j] objectForKey:@"TunnelObject"] forKey:@"TunnelObject"];
				}

				[tunnels replaceObjectAtIndex:j withObject:dict];

				match = YES;
			}
		}
		
		if(!match)
		{
			dict = [NSMutableDictionary dictionaryWithDictionary:[newTunnels objectAtIndex:i]];
			
			[[mainMenuTunnelsItem addItemWithTitle:[dict objectForKey:@"TunnelName"]
							action:@selector(toggleTunnel:) keyEquivalent:@""] setTarget:self];
			
			[[dockMenuTunnelsItem addItemWithTitle:[dict objectForKey:@"TunnelName"]
							action:@selector(toggleTunnel:) keyEquivalent:@""] setTarget:self];
			
			[[statusbarMenuTunnelsItem addItemWithTitle:[dict objectForKey:@"TunnelName"]
							action:@selector(toggleTunnel:) keyEquivalent:@""] setTarget:self];
			
			[tunnels addObject:[NSMutableDictionary dictionaryWithDictionary:dict]];
		}
	}
}

- (void)changeTunnelName:(NSString *)oldName toName:(NSString *)newName
{
	int i;
	
	if(!tunnels) { return; }
			
	for(i=0; i < [tunnels count]; i++) 
	{
		if([[[tunnels objectAtIndex:i] objectForKey:@"TunnelName"] isEqualToString:oldName])
		{
			[[tunnels objectAtIndex:i] setObject:newName forKey:@"TunnelName"];
			
			[[mainMenuTunnelsItem itemWithTitle:oldName] setTitle:newName];
			[[statusbarMenuTunnelsItem itemWithTitle:oldName] setTitle:newName];
			[[dockMenuTunnelsItem itemWithTitle:oldName] setTitle:newName];
			
			return;
		}
	}
}

- (void)setToolTipForActiveTunnels
{
	Controller *controller = [Controller currentController];
	int i;
	int active = 0;
	
	if(!tunnels) { 
		[controller setToolTip:@""];
		return; 
	}
	
	for(i=0; i < [tunnels count]; i++) 
	{
		if([[tunnels objectAtIndex:i] objectForKey:@"TunnelObject"])
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

- (void)removeTunnelWithName:(NSString *)name
{
	SSHTunnel *tunnel;
	int i;
	
	if(!tunnels) { return; }
		
	for(i=0; i < [tunnels count]; i++) 
	{
		if([[[tunnels objectAtIndex:i] objectForKey:@"TunnelName"] isEqualToString:name])
		{
			tunnel = [[tunnels objectAtIndex:i] objectForKey:@"TunnelObject"];
			
			if(tunnel)
			{
				[tunnel closeTunnel];
			}
			
			[tunnels removeObjectAtIndex:i];

			[mainMenuTunnelsItem removeItem:[mainMenuTunnelsItem itemWithTitle:name]];
			[dockMenuTunnelsItem removeItem:[dockMenuTunnelsItem itemWithTitle:name]];
			[statusbarMenuTunnelsItem removeItem:[statusbarMenuTunnelsItem itemWithTitle:name]];
		}
	}
}

- (void)closeAllTunnels
{
	int i;
	
	if(!tunnels) { return; }
	
	for(i=0; i < [tunnels count]; i++) 
	{
		if([[tunnels objectAtIndex:i] objectForKey:@"TunnelObject"]) 
		{
			SSHTunnel *tunnel = [[tunnels objectAtIndex:i] objectForKey:@"TunnelObject"];
			NSString *name = [[tunnels objectAtIndex:i] objectForKey:@"TunnelName"];
			
			[tunnel closeTunnel];
			[[tunnels objectAtIndex:i] removeObjectForKey:@"TunnelObject"];
			
			[[mainMenuTunnelsItem itemWithTitle:name] setState:NO];
			[[statusbarMenuTunnelsItem itemWithTitle:name] setState:NO];
			[[dockMenuTunnelsItem itemWithTitle:name] setState:NO];
		}
	}
	
	[self setToolTipForActiveTunnels];
}

- (void)launchAfterSleepTunnels
{
	SSHTunnel *tunnel;
	NSString *name;

	int i;
	
	if(!tunnels) { return; }
	
	for(i=0; i < [tunnels count]; i++) 
	{
		if([[tunnels objectAtIndex:i] objectForKey:@"LaunchAfterSleep"]) 
		{
			/* First kill the tunnel, if it's still open. */
			if([[tunnels objectAtIndex:i] objectForKey:@"TunnelObject"]) 
			{
				tunnel = [[tunnels objectAtIndex:i] objectForKey:@"TunnelObject"];
				name = [[tunnels objectAtIndex:i] objectForKey:@"TunnelName"];
			
				[tunnel closeTunnel];
				[[tunnels objectAtIndex:i] removeObjectForKey:@"TunnelObject"];
			
				[[mainMenuTunnelsItem itemWithTitle:name] setState:NO];
				[[statusbarMenuTunnelsItem itemWithTitle:name] setState:NO];
				[[dockMenuTunnelsItem itemWithTitle:name] setState:NO];
			}

			[self openTunnelWithDict:[tunnels objectAtIndex:i]];
		}
	}
	
	[self setToolTipForActiveTunnels];
}

- (void)toggleTunnel:(id)sender
{
	NSMutableDictionary *dict;
	int i;
	SSHTunnel *tunnel;
	
	dict = NULL;
	
	if(!tunnels) { return; }
	
	for(i=0; i < [tunnels count]; i++) 
	{
		if([[[tunnels objectAtIndex:i] objectForKey:@"TunnelName"] isEqualToString:[sender title]]) 
		{
			dict = [tunnels objectAtIndex:i];
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
	int i, last_terminated;
	NSString *output;
	BOOL fails_exceeded = NO;
		
	if(!contextInfo) {
		return;
	}

	[[mainMenuTunnelsItem itemWithTitle:contextInfo] setState:NO];
	[[statusbarMenuTunnelsItem itemWithTitle:contextInfo] setState:NO];
	[[dockMenuTunnelsItem itemWithTitle:contextInfo] setState:NO];
	
	if(!tunnels) { return; }

	for(i=0; i < [tunnels count]; i++) 
	{
		if([[[tunnels objectAtIndex:i] objectForKey:@"TunnelName"] isEqualToString:contextInfo]) 
		{
			SSHTunnel *tunnel = [[tunnels objectAtIndex:i] objectForKey:@"TunnelObject"];

			if(tunnel) 
			{
				last_terminated = 0;
				fails_exceeded = NO;
				
				output = [tunnel getOutput];
				
				[[tunnels objectAtIndex:i] removeObjectForKey:@"TunnelObject"];

				if([[tunnels objectAtIndex:i] objectForKey:@"LastTerminated"]) 
				{
					last_terminated = [[[tunnels objectAtIndex:i] objectForKey:@"LastTerminated"] intValue];
				}

				if((last_terminated) && ((time(NULL) - last_terminated) < 300)) 
				{
					fails_exceeded = YES;
					[[tunnels objectAtIndex:i] removeObjectForKey:@"LastTerminated"];
				} 
				
				else if((allKeysOnAgent) && ([output length] < 1))
				{
					[[tunnels objectAtIndex:i] setObject:[NSNumber numberWithInt:time(NULL)] forKey:@"LastTerminated"];
					[self openTunnelWithDict:[tunnels objectAtIndex:i]];
				}

				if((fails_exceeded) && ([output length] > 0)) 
				{
					[self warningPanelWithTitle:local(@"TunnelTerminated") 
							 andMessage:[NSString stringWithFormat:@"(%@) %@",
								 [[tunnels objectAtIndex:i] objectForKey:@"TunnelName"],
								 local(@"TunnelTerminatedAndCouldNotBeRestarted")]];
				}
				
				else if((!fails_exceeded) && (!allKeysOnAgent) && ([output length] < 1)) {
					[self warningPanelWithTitle:local(@"TunnelTerminated") 
							 andMessage:[NSString stringWithFormat:@"(%@) %@",
								 [[tunnels objectAtIndex:i] objectForKey:@"TunnelName"],
								 local(@"TunnelTerminatedAndCouldNotBeRestarted")]];
				}

				else if([output isEqualToString:@"tunnel failed\n"]) 
				{
					[self warningPanelWithTitle:local(@"TunnelForwardingFailed") 
							 andMessage:[NSString stringWithFormat:@"(%@) %@",
								 [[tunnels objectAtIndex:i] objectForKey:@"TunnelName"],
								 local(@"ForwardingFailedDuringInitialization")]];
				} 
				
				else if([output length] > 0) 
				{
					[self warningPanelWithTitle:local(@"TunnelSetupFailed")
							 andMessage:[NSString stringWithFormat:@"(%@) Error:\n%@", 
								 [[tunnels objectAtIndex:i] objectForKey:@"TunnelName"],
								 output]];
				}
				
				else if(fails_exceeded)
				{
					[self warningPanelWithTitle:local(@"TunnelTerminated")
							 andMessage:[NSString stringWithFormat:@"(%@) %@",
								 [[tunnels objectAtIndex:i] objectForKey:@"TunnelName"],
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
	int i;

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
			
	for(i=0; i < [tunnels count]; i++) {
		if((![[tunnels objectAtIndex:i] objectForKey:@"TunnelObject"]) &&
			([[tunnels objectAtIndex:i] objectForKey:@"LaunchOnAgentFilled"])) {
			
			NSMutableDictionary *dict = [tunnels objectAtIndex:i];

			[self openTunnelWithDict:dict];
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
	SSHTunnel *tunnel = [[[SSHTunnel alloc] init] autorelease];
	
	[tunnel setTunnelHost:[dict objectForKey:@"TunnelHostname"]
			withPort:[[dict objectForKey:@"TunnelPort"] intValue]
			andUser:[dict objectForKey:@"TunnelUser"]];

	if([dict objectForKey:@"Compression"])
	{
		[tunnel setCompression:YES];
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
			[tunnel addRemotePortForwardWithPort:[[[[dict objectForKey:@"LocalPortForwards"] objectAtIndex:i] objectForKey:@"RemotePort"] intValue]
						localHost:[[[dict objectForKey:@"LocalPortForwards"] objectAtIndex:i] objectForKey:@"LocalHost"]
						localPort:[[[[dict objectForKey:@"LocalPortForwards"] objectAtIndex:i] objectForKey:@"LocalPort"] intValue]
			];
		}
	}
	
	[tunnel handleClosedWithSelector:@selector(handleClosedTunnels:) toObject:self 
				withInfo:[dict objectForKey:@"TunnelName"]];
	
	if([tunnel openTunnel]) 
	{
		[dict setObject:tunnel forKey:@"TunnelObject"];
	
		[[mainMenuTunnelsItem itemWithTitle:[dict objectForKey:@"TunnelName"]] setState:YES];
		[[statusbarMenuTunnelsItem itemWithTitle:[dict objectForKey:@"TunnelName"]] setState:YES];
		[[dockMenuTunnelsItem itemWithTitle:[dict objectForKey:@"TunnelName"]] setState:YES];
		
		[self setToolTipForActiveTunnels];
	}

}

/* This method displays a warning. */
- (void)warningPanelWithTitle:(NSString *)title andMessage:(NSString *)message
{
	[NSApp activateIgnoringOtherApps:YES];
	NSRunAlertPanel(title, message, nil, nil, nil);
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
