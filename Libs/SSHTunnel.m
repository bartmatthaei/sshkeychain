#import "SSHTunnel.h"

#import "PreferenceController.h"

@implementation SSHTunnel

- (id)init
{
	if(self = [super init])
	{
		tunnelHost = NULL;
		tunnelPort = 0;
		tunnelUser = NULL;

		localPortForwards = [[NSMutableArray alloc] init];
		remotePortForwards = [[NSMutableArray alloc] init];
		dynamicPortForwards = [[NSMutableArray alloc] init];
		
		closeSelector = NULL;
		closeObject = NULL;
		closeInfo = NULL;

		compression = NO;
		
		tunnel = nil;
		thePipe = nil;
	}

	return self;
}

- (void)dealloc
{
	[localPortForwards release];
	[remotePortForwards release];
	[dynamicPortForwards release];
	[tunnelHost release];
	[tunnelUser release];
	[tunnel release];
	[thePipe release];
	
	[super dealloc];
}

/* Set the tunnel host, port and user. */
- (BOOL)setTunnelHost:(NSString *)host withPort:(int)port andUser:(NSString *)user
{
	if(open)
	{
		return NO;
	}
	
	[tunnelHost autorelease];
	tunnelHost = [[NSString stringWithString:host] retain];
	tunnelPort = port;
	[tunnelUser autorelease];
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

/* Set remote access. */
- (BOOL)setRemoteAccess:(BOOL)theBool
{
	if(open)
	{
		return NO;
	}
	
	remoteAccess = theBool;
	
	return YES;
}

/* Add a local port forward. */
- (BOOL)addLocalPortForwardWithPort:(int)lport remoteHost:(NSString *)rhost remotePort:(int)rport
{
	if((open) || (lport < 1) || (lport > 65535) || (rport < 1) || (rport > 65535))
	{
		return NO;
	}

	[localPortForwards addObject:[NSArray arrayWithObjects:[NSNumber numberWithInt:lport], rhost, [NSNumber numberWithInt:rport], nil]];

	return YES;
}

/* Add a remote port forward. */
- (BOOL)addRemotePortForwardWithPort:(int)rport localHost:(NSString *)lhost localPort:(int)lport
{
	if((open) || (lport < 1) || (lport > 65535) || (rport < 1) || (rport > 65535))
	{
		return NO;
	}

	[remotePortForwards addObject:[NSArray arrayWithObjects:[NSNumber numberWithInt:rport], lhost, [NSNumber numberWithInt:lport], nil]];

	return YES;
}

/* Add a dynamic port forward. */
- (BOOL)addDynamicPortForwardWithPort:(int)lport
{
	if((open) || (lport < 1) || (lport > 65535))
	{
		return NO;
	}
	
	[dynamicPortForwards addObject:[NSNumber numberWithInt:lport]];
	
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

	
	/*  We want to use our internal build of ssh if we have dynamic ports and the sshToolsPathString
		is /usr/bin. This is because the Panther-provided copy of ssh (and perhaps Jaguar-provided,
		I don't know) is broken wrt. dynamic ports */
	// Of course, since the build of ssh only works on Panther, we have to disable Dynamic Ports
	// entirely under Jaguar
	NSString *toolPath;
	NSString *sshPathString = [[NSUserDefaults standardUserDefaults] stringForKey:sshToolsPathString];
	if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_2) {
		// It's Jaguar
		toolPath = [sshPathString stringByAppendingPathComponent:@"ssh"];
	} else {
		if([dynamicPortForwards count] > 0 && [[sshPathString stringByStandardizingPath] isEqualToString:@"/usr/bin"]) {
			/* Time to use our internal build */
			toolPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"ssh"];
		} else {
			toolPath = [sshPathString stringByAppendingPathComponent:@"ssh"];
		}
	}
	arguments = [NSMutableArray arrayWithObject:toolPath];
	
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
	
	// No dynamic ports under Jaguar
	if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_2) {
		for(i=0; i < [dynamicPortForwards count]; i++)
		{
			[arguments addObject:[NSString stringWithFormat:@"-D%d",
				[[dynamicPortForwards objectAtIndex:0] intValue]]];
		}
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
	
	if(remoteAccess)
	{
		[arguments addObject:@"-g"];
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
	
	thePipe = [[NSPipe alloc] init];

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
	tunnel = nil;
	[thePipe release];
	thePipe = nil;
}

@end
