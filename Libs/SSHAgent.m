#import "SSHAgent.h"

#import "SSHKeychain.h"
#import "SSHTool.h"
#import "PreferenceController.h"

#include <string.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <errno.h>

#define BUFSIZE 4096

SSHAgent *currentAgent;

/* This function resides in Controller.m. */
extern NSString *local(NSString *theString);

@implementation SSHAgent

/* Return the current agent, if set. */
+ (id)currentAgent
{
	if (!currentAgent)
		currentAgent = [[SSHAgent alloc] init];
	
	return currentAgent;
}

- (id)init
{
	if (!(self = [super init]))
		return nil;

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(keysOnAgentStatusChange:) name:@"AgentFilled" object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(keysOnAgentStatusChange:) name:@"AgentEmptied" object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(keysOnAgentStatusChange:) name:@"KeysOnAgentUnknown" object:nil];
	
	agentLock = [[NSLock alloc] init];
	
	return self;
}

- (void)dealloc
{
	currentAgent = nil;
	[agentLock lock];
	[socketPath release];
	[agentSocketPath release];
	[keysOnAgent release];
	[agentLock unlock];
	[agentLock release];

	[super dealloc];
}

/* Set the socket location for us to bind to. */
- (void)setSocketPath:(NSString *)path
{
	if ([self isRunning])
	{
		NSLog(@"setSocketPath: can't change path while the agent is running.");
		return;
	}

	[agentLock lock];
	NSString *oldPath = socketPath;
	socketPath = [path copy];
	[oldPath release];
	[agentLock unlock];
}

/* Get the socket path we bind to. */
- (NSString *)socketPath
{
	[agentLock lock];
	NSString *returnString = [[socketPath copy] autorelease];
	[agentLock unlock];

	return returnString;
}

/* Set the socket location ssh-agent listens to. */
- (void)setAgentSocketPath:(NSString *)path
{
	[agentLock lock];
	NSString *oldPath = agentSocketPath;
	agentSocketPath = [path copy];
	[oldPath release];
	[agentLock unlock];
}

/* Get the socket path the ssh-agent listens to. */
- (NSString *)agentSocketPath
{
	[agentLock lock];
	NSString *returnString = [[agentSocketPath copy] autorelease];
	[agentLock unlock];

	return returnString;
}


/* Return YES if the agent is (in theory) running, and NO if not. */
- (BOOL)isRunning
{
	return [agentTask isRunning];
}

/* Get the pid. */
- (int)PID
{
	[agentLock lock];
	int returnInt = thePID;
	[agentLock unlock];

	return returnInt;
}

- (void) setPID:(int)pid
{
	[agentLock lock];
	thePID = pid;
	[agentLock unlock];
}

/* Return the keys on agent since last notification. */
- (NSArray *)keysOnAgent
{
	[agentLock lock];
	NSArray *returnArray = [[keysOnAgent copy] autorelease];
	[agentLock unlock];

	return returnArray;
}

- (void) setKeysOnAgent:(NSArray *)keys
{
	[agentLock lock];
	NSArray *oldKeys = keysOnAgent;
	keysOnAgent = [keys copy];
	[oldKeys release];
	[agentLock unlock];
}


/* eric - 20070819 - Tried several variations before settling on this.  It gives us notification
    of task termination and unfortunatly NSPipe is very bad about dealing with libc apps that don't
	flush at the end of every line.  The sleep is a hack, but it works and will only happen one */
	
/* Start the agent. */
- (BOOL)start
{
	if ([self isRunning])
	{
		NSLog(@"Agent is already started");
		return NO;
	}

	[self setAgentSocketPath:nil];
	[self setPID:-1];
	
	/* Create temporary path for ssh-agent */
	char template[] = "/tmp/501/agent.XXXXXX";
	char *retVal = mktemp(template);
	if ( (long)retVal == -1 ) {
		NSLog(@"SSHAgent start: temp path could not be generated.");
		return NO;
	}
	NSString *tempPath = [NSString stringWithCString:retVal];
	NSLog(tempPath);

	/* Setup the agentTask and launch */
	agentTask = [[[NSTask alloc] init] retain];
	[agentTask setLaunchPath:@"/usr/bin/ssh-agent"];
	[agentTask setArguments:[NSArray arrayWithObjects:@"-c",@"-d",@"-a", tempPath, nil]];
	[agentTask launch];

	/* set paths and PID's... we already know them in advance */
	[self setAgentSocketPath: tempPath];
	[self setPID:[agentTask processIdentifier]];

	/* If the agent is not running, or the socket path is empty then stop the agent and fail */
	if (![self isRunning] || ![[self agentSocketPath] length])
	{
		NSLog(@"SSHAgent start: ssh-agent didn't give the output we expected");
		[self stop];
		return NO;
	}
	
	/* We need to give ssh-agent time to startup, it's an ugly hack but NSPipes wen't cutting it */
	sleep(1);

	/* Handle connections in a seperate thread. */
	[NSThread detachNewThreadSelector:@selector(handleAgentConnections) toTarget:self withObject:nil];
	
	/* Watch for terminaton of the agent */
	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(agentFailed:) 
		name:NSTaskDidTerminateNotification 
		object:agentTask];

	[[NSNotificationCenter defaultCenter]  postNotificationName:@"AgentStarted" object:nil];

	return YES;
}

/* Stop the agent. */
- (BOOL)stop
{
	/* We can't stop something if we it's not running */
	if (![self isRunning])
		return YES;

	/* We don't need to check if this fails. We clean up the variables either way. */
	[agentTask terminate];
	kill([self PID], SIGTERM);

	[self setAgentSocketPath:nil];
	[self closeSockets];
	[self setPID:0];
	[self setKeysOnAgent:nil];

	[[NSNotificationCenter defaultCenter]  postNotificationName:@"AgentStopped" object:nil];

	return YES;
}

/* Close our sockets. */
- (void)closeSockets
{
	close(theSocket);
	if ([[self socketPath] fileSystemRepresentation])
		unlink([[self socketPath] fileSystemRepresentation]);
}

/* Handle connections to our socket. */
- (void)handleAgentConnections
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	/* Fill the sockaddr_un structs. */
	struct sockaddr_un localSocketAddress;
	memset(&localSocketAddress, 0, sizeof(localSocketAddress));
	localSocketAddress.sun_family = AF_UNIX;
	strncpy(localSocketAddress.sun_path, [[self socketPath] fileSystemRepresentation], sizeof(localSocketAddress.sun_path));

	struct sockaddr_un remoteSocketAddress;
	memset(&remoteSocketAddress, 0, sizeof(remoteSocketAddress));
	remoteSocketAddress.sun_family = AF_UNIX;
	strncpy(remoteSocketAddress.sun_path, [[self agentSocketPath] fileSystemRepresentation], sizeof(remoteSocketAddress.sun_path));

	/* Make a socket. */
	if ((theSocket = socket(AF_UNIX, SOCK_STREAM, 0)) < 0)
	{
		NSLog(@"handleAgentConnections: socket() failed");
		[self stop];
		[pool release];
		return;
	}

	/* Bind it. */
	if (bind(theSocket, (struct sockaddr *) &localSocketAddress, sizeof(localSocketAddress)) < 0)
	{
		unlink([[self socketPath] fileSystemRepresentation]);
		if (bind(theSocket, (struct sockaddr *) &localSocketAddress, sizeof(localSocketAddress)) < 0)
		{ 
			NSLog(@"handleAgentConnections: bind() failed");
			[self stop];
			[pool release];
			return;
		}
	}

	/* Listen to it. */
	if (listen(theSocket, 30) < 0)
	{
		NSLog(@"handleAgentConnections: listen() failed");
		[self stop];
		[pool release];
		return;
	}
	
	int usedFileDescriptors = 0;
	int allocatedFileDescriptors = 10;
	/* Allocate space for 10 int's, to keep track of fd's in use. */
	int *allFileDescriptors = malloc(sizeof(int) * allocatedFileDescriptors);
	if (!allFileDescriptors)
	{
		NSLog(@"handleAgentConnections: malloc() failed");
		[self stop];
		[pool release];
		return;
	}

	/* Make the listening socket nonblocking. */
	fcntl(theSocket, F_SETFL, O_NONBLOCK);

	fd_set readFileDescriptors;
	FD_ZERO(&readFileDescriptors);
	FD_SET(theSocket, &readFileDescriptors);

	int largestFileDescriptor = theSocket;

	/* Run a select over all available fd's. */
	int result;
	while ((result = select(largestFileDescriptor + 1, &readFileDescriptors, NULL, NULL, NULL)))
	{
		if (result == -1 && errno == EINTR)
			continue;

		/* If result == -1 and errno != EINTR, then shit has probably hit the fan. Exit. */
		else if (result == -1)
		{
			NSLog(@"handleAgentConnections: select() encountered a fatal error");
			[self stop];
			free(allFileDescriptors);
			[pool release];
			return;
		}

		/* If the listening socket is part of the active set, then accept the connection and add it to the list of fd's. */
		socklen_t sockaddrSize = (socklen_t) sizeof(struct sockaddr);
		int newLocalFileDescriptor;
		if (FD_ISSET(theSocket, &readFileDescriptors) && (newLocalFileDescriptor = accept(theSocket, (struct sockaddr *) &localSocketAddress, &sockaddrSize)) > -1)
		{
		
			if (allocatedFileDescriptors < usedFileDescriptors + 2)
			{
				allocatedFileDescriptors *= 2;
				allFileDescriptors = realloc(allFileDescriptors, (sizeof(int) * allocatedFileDescriptors  * 2));
				if (!allFileDescriptors)
				{
					NSLog(@"handleAgentConnections: realloc() failed");
					[self stop];
					[pool release];
					return;
				}
			}

			/* Add the accepted socket to the list. */
			allFileDescriptors[usedFileDescriptors++] = newLocalFileDescriptor;

			/* Create a socket. */
			int newRemoteFileDescriptor;
			if ((newRemoteFileDescriptor = socket(AF_UNIX, SOCK_STREAM, 0)) < 0)
			{
				NSLog(@"handleAgentConnections: Socket creation failed");
				allFileDescriptors[--usedFileDescriptors] = -1;
				close(newLocalFileDescriptor);
				[self stop];
				free(allFileDescriptors);
				[pool release];
				return;
			}

			/* Connect to the ssh-agent. */
			else if (connect(newRemoteFileDescriptor, (struct sockaddr *) &remoteSocketAddress, sizeof(remoteSocketAddress)) < 0)
			{
				NSLog(@"handleAgentConnections: Connecting to ssh-agent failed");
				allFileDescriptors[--usedFileDescriptors] = -1;
				close(newLocalFileDescriptor);
				close(newRemoteFileDescriptor);
				[self stop];
				free(allFileDescriptors);
				[pool release];
				return;
			}

			allFileDescriptors[usedFileDescriptors++] = newRemoteFileDescriptor;
		}

		/* Check activity of each fd in the list. */
		int i;
		for(i = 0; i < usedFileDescriptors; i++)
		{
			if (!FD_ISSET(allFileDescriptors[i], &readFileDescriptors))
				continue;

			char readBuffer[BUFSIZE];
			
			/* If i is even, forward it's traffic to the agent. */
			if ((i & 1) == 0 && allFileDescriptors[i+1] > 0)
			{
				int len = read(allFileDescriptors[i], readBuffer, BUFSIZE);

				/* If len < 1, the connection is closed. Close all fd's of the pipe. */
				if (len < 1)
				{
					close(allFileDescriptors[i]);
					close(allFileDescriptors[i+1]);
					allFileDescriptors[i] = allFileDescriptors[usedFileDescriptors-2];
					allFileDescriptors[i+1] = allFileDescriptors[usedFileDescriptors-1];
					usedFileDescriptors -= 2;
					continue;
				}
				
				/* If read byte is \1 or \11, and there are no keys on the chain, run inputFromClient: */
				if ((len == 1 && (readBuffer[0] == 11 || readBuffer[0] == 1)) || (len == 5 && (readBuffer[4] == 11 || readBuffer[4] == 1)))
				{
					NSArray *array = [NSArray arrayWithObjects:[NSNumber numberWithInt:allFileDescriptors[i+1]], 
								[NSString stringWithCString:readBuffer length:len], [NSNumber numberWithInt:len],
								[NSNumber numberWithInt:allFileDescriptors[i]], nil];

					[NSThread detachNewThreadSelector:@selector(inputFromClient:) toTarget:self withObject:array]; 
					continue;
				}

				write(allFileDescriptors[i+1], readBuffer, len);

				/* If read byte is \9 or \19, remove all keys from the agent. (\9 and \19 is a remove_all_keys request) */
				if (((len == 1 && (readBuffer[0] == 9 || readBuffer[0] == 19)) || (len == 5 && (readBuffer[4] == 9 || readBuffer[4] == 19)))
					 && [[self keysOnAgent] count] > 0)
				{
					[[SSHKeychain currentKeychain] removeKeysFromAgent];
				}

				/* If the first byte is \8 or \18, a key is removed ...
				   or if the first byte is \7 or \17, a key is added. */
				else if (((readBuffer[0] == 8 || readBuffer[0] == 18) && [[self keysOnAgent] count] > 0) ||
					 (readBuffer[0] == 7 || readBuffer[0] == 17))
				{
					[self setKeysOnAgent:[[SSHAgent currentAgent] currentKeysOnAgent]];
					[[NSNotificationCenter defaultCenter]  postNotificationName:@"KeysOnAgentUnknown" object:nil];
				}
			}

			/* If i is uneven, forward it's traffic to the client. */
			else if (allFileDescriptors[i-1] > 0)
			{
				int len = read(allFileDescriptors[i], readBuffer, BUFSIZE);

				/* If r < 1, the connection is closed. Close all fd's of the pipe. */
				if (len < 1)
				{
					close(allFileDescriptors[i]);
					close(allFileDescriptors[i-1]);
					allFileDescriptors[i] = allFileDescriptors[usedFileDescriptors-1];
					allFileDescriptors[i-1] = allFileDescriptors[usedFileDescriptors-2];
					usedFileDescriptors -= 2;
					continue;
				}
				write(allFileDescriptors[i-1], readBuffer, len);
			}
		}
	

		/* Refill the fd_set. */
		FD_ZERO(&readFileDescriptors);
		FD_SET(theSocket, &readFileDescriptors);
		largestFileDescriptor = theSocket;
		
		for (i = 0; i < usedFileDescriptors; i++)
		{
			FD_SET(allFileDescriptors[i], &readFileDescriptors);
			if (allFileDescriptors[i] > largestFileDescriptor)
				largestFileDescriptor = allFileDescriptors[i];
		}
	}

	free(allFileDescriptors);
	[pool release];
}

/* When there's a request from a client, this method is called. */
- (void)inputFromClient:(id)object
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	int destinationFileDescriptor = [[object objectAtIndex:0] intValue];
	const char *readBuffer = [[object objectAtIndex:1] cString];
	int len = [[object objectAtIndex:2] intValue];

	if ([[NSUserDefaults standardUserDefaults] boolForKey:AskForConfirmationString]) 
	{
		/* Dictionary for the panel. */
		NSMutableDictionary *dict = [NSMutableDictionary dictionary];
		
		[dict setObject:local(@"ConfirmationPanelTitle") forKey:(NSString *)kCFUserNotificationAlertHeaderKey];
		[dict setObject:local(@"ConfirmationPanelText") forKey:(NSString *)kCFUserNotificationAlertMessageKey];
		
		[dict setObject:[NSURL fileURLWithPath:[[[NSBundle mainBundle] resourcePath]
					stringByAppendingString:@"/SSHKeychain.icns"]] forKey:(NSString *)kCFUserNotificationIconURLKey];
		
		[dict setObject:local(@"Yes") forKey:(NSString *)kCFUserNotificationDefaultButtonTitleKey];
		[dict setObject:local(@"No") forKey:(NSString *)kCFUserNotificationAlternateButtonTitleKey];
		
		/* Display a passphrase request notification. */
		SInt32 error;
		CFUserNotificationRef notification = CFUserNotificationCreate(nil, 30, CFUserNotificationSecureTextField(0), &error, (CFDictionaryRef)dict);
		
		/* If we couldn't receive a response, return. */
		CFOptionFlags response;
		if (error || CFUserNotificationReceiveResponse(notification, 0, &response) || (response & 0x3) != kCFUserNotificationDefaultResponse)
		{
			int sourceFileDescriptor = [[object objectAtIndex:3] intValue];

			if ((len == 1 && readBuffer[0] == 1) || (len == 5 && readBuffer[4] == 1))
			{
				/* Return \2. */
				write(sourceFileDescriptor, "\0\0\0\5\2\0\0\0\0", 9);

				[pool release];
				return;
			}
		
			else if ((len == 1 && readBuffer[0] == 11) || (len == 5 && readBuffer[4] == 11))
			{
				/* Return \12. */
				write(sourceFileDescriptor, "\0\0\0\5\f\0\0\0\0", 9);

				[pool release];
				return;
			}
		}
	}

	if ([[self keysOnAgent] count] < 1 && [[NSUserDefaults standardUserDefaults] boolForKey:AddKeysOnConnectionString])
	{
		SSHKeychain *keychain = [SSHKeychain currentKeychain];
		if ([keychain count] > 0)
			[keychain addKeysToAgent];
	}

	/* Write the buffer to the agent. */
	write(destinationFileDescriptor, readBuffer, len);
	[pool release];
}

/* this method is called from a NSTask notification when the agent dies out from underneath us */
- (void)agentFailed:(NSNotification *)notification
{
	/* do nothing if the notification is not for out current agent */
	if ( [notification object] != agentTask ) {
		return;
	}
	
	/* Dictionary for the panel. */
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];

	[dict setObject:local(@"AgentTerminatedPanelTitle") forKey:(NSString *)kCFUserNotificationAlertHeaderKey];
	[dict setObject:local(@"AgentTerminatedPanelText") forKey:(NSString *)kCFUserNotificationAlertMessageKey];

	[dict setObject:[NSURL fileURLWithPath:[[[NSBundle mainBundle] resourcePath]
				stringByAppendingString:@"/SSHKeychain.icns"]] forKey:(NSString *)kCFUserNotificationIconURLKey];

	[dict setObject:local(@"Yes") forKey:(NSString *)kCFUserNotificationDefaultButtonTitleKey];
	[dict setObject:local(@"No") forKey:(NSString *)kCFUserNotificationAlternateButtonTitleKey];

	/* Display a passphrase request notification. */
	SInt32 error;
	CFOptionFlags response;
	CFUserNotificationRef notificationRef = CFUserNotificationCreate(nil, 30, CFUserNotificationSecureTextField(0), &error, (CFDictionaryRef)dict);

	/* If we couldn't receive a response, return nil. */
	if (error || CFUserNotificationReceiveResponse(notificationRef, 0, &response))
	{
		return;
	}

	/* If OK was pressed, add the keys. */
	if ((response & 0x3) == kCFUserNotificationDefaultResponse)
		[self start];
}

/* Get current keys on agent. */
- (NSArray *)currentKeysOnAgent
{
	NSString *line;

	if (![self isRunning])
		return nil;

	/* Initialize a ssh-add SSHTool, set the arguments to -l for a list of keys. */
	SSHTool *theTool = [SSHTool toolWithName:@"ssh-add"];
	[theTool setArgument:@"-l"];

	/* Set the SSH_AUTH_SOCK environment variable so ssh-add can talk to the real agent. */
	[theTool setEnvironmentVariable:@"SSH_AUTH_SOCK" withValue:[self agentSocketPath]];

	/* Launch the tool and retrieve stdout. */
	NSString *theOutput = [theTool launchForStandardOutput];
	if (!theOutput)
		return nil;

	if ([theOutput isEqualToString:@"The agent has no identities.\n"])
		return nil;

	NSMutableArray *keys = [NSMutableArray array];
	NSArray *lines = [theOutput componentsSeparatedByString:@"\n"];

	NSEnumerator *e = [lines objectEnumerator];
	while (line = [e nextObject])
	{
		/* Split the line with delimiter " ". */
		NSArray *columns = [line componentsSeparatedByString:@" "];

		if ([columns count] != 4)
			continue;
		
		NSString *rawKeyType = [columns objectAtIndex:3];
		NSString *parsedKeyType = @"?";
		if ([rawKeyType isEqualToString:@"(RSA1)"])
			parsedKeyType = @"RSA1";
		else if ([rawKeyType isEqualToString:@"(RSA)"])
			parsedKeyType = @"RSA";
		else if([rawKeyType isEqualToString:@"(DSA)"])
			parsedKeyType = @"DSA";

		NSArray *key = [NSArray arrayWithObjects:
					[NSString stringWithString:[[columns objectAtIndex:2] stringByAbbreviatingWithTildeInPath]],
					[NSString stringWithString:[columns objectAtIndex:1]], 
					[NSString stringWithString:parsedKeyType],
					nil];
		[keys addObject:key];
	}

	if ([keys count])
		return [NSArray arrayWithArray:keys];

	return nil;
}

/* This method is called when keys are added/removed from the agent. */
- (void)keysOnAgentStatusChange:(NSNotification *)notification
{
	if ([[notification name] isEqualToString:@"AgentEmptied"])
		[self setKeysOnAgent:nil];

	else if ([[notification name] isEqualToString:@"AgentFilled"])
		[self setKeysOnAgent:[[SSHAgent currentAgent] currentKeysOnAgent]];
}

@end
