/* $Id: SSHTunnel.m,v 1.1 2004/06/23 08:12:21 bart Exp $ */

#import "SSHTunnel.h"

#import "PreferenceController.h"

@implementation SSHTunnel

- (id)init
{
	if((self = [super init]) == NULL)
	{
		return NULL;
	}

	tunnelHost = NULL;
	tunnelPort = 0;
	tunnelUser = NULL;

	localPortForwards = [[[[NSMutableArray alloc] init] autorelease] retain];
	remotePortForwards = [[[[NSMutableArray alloc] init] autorelease] retain];
	
	closeSelector = NULL;
	closeObject = NULL;
	closeInfo = NULL;

	compression = NO;

	return self;
}

- (void)dealloc
{
	[super dealloc];
}

/* Set the tunnel host, port and user. */
- (BOOL)setTunnelHost:(NSString *)host withPort:(int)port andUser:(NSString *)user
{
	if(open)
	{
		return NO;
	}

	tunnelHost = [[NSString stringWithString:host] retain];
	tunnelPort = port;
	tunnelUser = [[NSString stringWithString:user] retain];

	return YES;
}

/* Set compression. */
- (BOOL)setCompression:(BOOL)theBool
{
	if(open)
	{
		return NO;
	}

	compression = theBool;

	return YES;
}

/* Add a local port forward. */
- (BOOL)addLocalPortForwardWithPort:(int)lport remoteHost:(NSString *)rhost remotePort:(int)rport;
{
	if((open) || (lport < 1) || (lport > 65535) || (rport < 1) || (rport > 65535))
	{
		return NO;
	}

	[localPortForwards addObject:[NSArray arrayWithObjects:[NSNumber numberWithInt:lport], rhost, [NSNumber numberWithInt:rport], nil]];

	return YES;
}

/* Add a remote port forward. */
- (BOOL)addRemotePortForwardWithPort:(int)rport localHost:(NSString *)lhost localPort:(int)lport;
{
	if((open) || (lport < 1) || (lport > 65535) || (rport < 1) || (rport > 65535))
	{
		return NO;
	}

	[remotePortForwards addObject:[NSArray arrayWithObjects:[NSNumber numberWithInt:rport], lhost, [NSNumber numberWithInt:lport], nil]];

	return YES;
}

/* Get the output after the task has finished. */
- (NSString *)getOutput
{
	return [[[NSString alloc] initWithData:[[thePipe fileHandleForReading] readDataToEndOfFile] encoding:NSASCIIStringEncoding] autorelease];
}

/* Handle closed tunnel notifications. */
- (void)handleClosedWithSelector:(SEL)theSelector toObject:(id)theObject withInfo:(id)theInfo
{

	if((!theSelector) || (!theObject))
	{
		return;
	}
	
	closeSelector = theSelector;
	closeObject = theObject;
	
	if(theInfo)
	{
		closeInfo = theInfo;
	}
	
	else
	{
		closeInfo = NULL;
	}
}

/* Return YES if the tunnel is open, and NO if not. */
- (BOOL)isOpen
{
	return open;
}

- (BOOL)openTunnel
{
	int i;
	NSMutableArray *arguments;

	/* If the PID is > 1, the tunnel should be open. */
	if([self isOpen])
	{
		return NO;
	}

	if((!tunnelHost) || ([tunnelHost isEqualToString:@""]))
	{
		return NO;
	}

	open = YES;

	/* Initialize a ssh SSHTool, and set the arguments. */
	tunnel = [[SSHTool toolWithPath:[[[NSBundle mainBundle] resourcePath] 
			stringByAppendingPathComponent:@"TunnelRunner"]] retain];

	
	arguments = [NSMutableArray arrayWithObjects:
							[[[NSUserDefaults standardUserDefaults] stringForKey:sshToolsPathString] 
										stringByAppendingPathComponent:@"ssh"],
							nil
			];

	for(i=0; i < [localPortForwards count]; i++)
	{
			[arguments addObject:[NSString stringWithFormat:@"-L%d:%@:%d", [[[localPortForwards objectAtIndex:i] objectAtIndex:0] intValue], 
											[[localPortForwards objectAtIndex:i] objectAtIndex:1],
											[[[localPortForwards objectAtIndex:i] objectAtIndex:2] intValue]]
			];
	}

	for(i=0; i < [remotePortForwards count]; i++)
	{
			[arguments addObject:[NSString stringWithFormat:@"-L%d:%@:%d", [[[remotePortForwards objectAtIndex:i] objectAtIndex:0] intValue], 
											[[remotePortForwards objectAtIndex:i] objectAtIndex:1],
											[[[remotePortForwards objectAtIndex:i] objectAtIndex:2] intValue]]
			];
	}

	if((tunnelPort > 0) && (tunnelPort < 65535))
	{
			[arguments addObject:[NSString stringWithFormat:@"-p %d", tunnelPort]];
	}

	[arguments addObject:@"-N"];
	[arguments addObject:@"-t"];
	[arguments addObject:@"-x"];

	if(compression)
	{
		[arguments addObject:@"-C"];
	}
	
	if((tunnelUser) && (![tunnelUser isEqualToString:@""]))
	{
			[arguments addObject:[NSString stringWithFormat:@"%@@%@", tunnelUser, tunnelHost]];
	}

	else
	{
			[arguments addObject:[NSString stringWithFormat:@"%@", tunnelHost]];
	}
		
	[tunnel setArguments:arguments];
	
	/* Set the SSH_ASKPASS + DISPLAY environment variables, so the tool can ask for a passphrase. */
	[tunnel setEnvironmentVariable:@"SSH_ASKPASS" withValue:
		[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"PassphraseRequester"]];
	
	[tunnel setEnvironmentVariable:@"DISPLAY" withValue:@":0"];
	[tunnel setEnvironmentVariable:@"INTERACTION" withValue:@"1"];
	[tunnel setEnvironmentVariable:@"SSH_AUTH_SOCK" 
			     withValue:[[NSUserDefaults standardUserDefaults] stringForKey:socketPathString]];

	if((closeSelector) && (closeObject)) {
		[tunnel handleTerminateWithSelector:closeSelector toObject:closeObject withInfo:closeInfo];
	}
	
	thePipe = [[[[NSPipe alloc] init] autorelease] retain];

	[[tunnel task] setStandardOutput:thePipe];
	
	/* Launch ssh. */
	if([tunnel launch] == NO) {
		return NO;
	}
	
	open = YES;

	return YES;
}

- (void)closeTunnel
{	
	if((open) && (tunnel)) {
		[tunnel terminate];
	}

	[tunnel release];
}

@end
