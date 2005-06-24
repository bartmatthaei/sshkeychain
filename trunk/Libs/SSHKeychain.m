#import "SSHKeychain.h"
#import "PreferenceController.h"

#import "SSHKey.h"
#import "SSHTool.h"

#include <unistd.h>

SSHKeychain *currentKeychain;

@implementation SSHKeychain

/* Return the global keychain, if set. */
+ (id)currentKeychain
{
	if(currentKeychain == nil)
	{
		[self keychainWithPaths:[[NSUserDefaults standardUserDefaults] arrayForKey:@"Keys"]];
	}

	return currentKeychain;
}

/* Construct a SSHKeychain object with thePaths as SSHKey's. */
+ (id)keychainWithPaths:(NSArray *)paths
{
	return [[self alloc] initWithPaths:paths];
}

- (id)initWithPaths:(NSArray *)paths
{
	SSHKey *theKey;

	if((self = [super init]) == nil)
	{
		return nil;
	}

	[keychainLock lock];
	keychain = [[NSMutableArray array] retain];

	int i;

	for(i=0; i < [paths count]; i++)
	{
		/* If the key is valid, add it to the keychain array. */
		theKey = [SSHKey keyWithPath:[paths objectAtIndex:i]];
		if(theKey != nil)
		{
			[keychain addObject:theKey];
		}
	}

	[keychainLock unlock];
	
	[lastAddedLock lock];
	lastAdded = -1;
	[lastAddedLock unlock];
	
	currentKeychain = self;
	
	return self;
}

- (id)init
{
	if((self = [super init]) == nil)
	{
		return nil;
	}

	addingKeysLock = [[NSLock alloc] init];
	keychainLock = [[NSLock alloc] init];
	lastAddedLock = [[NSLock alloc] init];

	return self;
}

- (void)dealloc
{
	currentKeychain = nil;

	int i;
	for(i=0; i < [keychain count]; i++)
	{
		[[keychain objectAtIndex:i] release];
	}

	[keychainLock lock];

	[keychain release];
	keychain = nil;

	[keychainLock unlock];

	[addingKeysLock dealloc];
	[lastAddedLock dealloc];
	
	[super dealloc];
}

/* Reset the keychain, and add thePaths as keys. */
- (void)resetToKeysWithPaths:(NSArray *)paths
{
	SSHKey *theKey;

	[keychainLock lock];

	if(keychain != nil)
	{
		[keychain release];
	}
	
	keychain = [[NSMutableArray array] retain];

	int i;

	for(i=0; i < [paths count]; i++)
	{
		/* If the key is valid, add it to the keychain array. */
		theKey = [SSHKey keyWithPath:[paths objectAtIndex:i]];
		if(theKey != nil)
		{
			[keychain addObject:theKey];
		}
	}

	[keychainLock unlock];
}

/* Set the socket path we should use for ssh-add. */
- (void)setAgentSocketPath:(NSString *)path
{
	agentSocketPath = [[NSString stringWithString:path] retain];
}

/* Tell the receiver if we're adding keys. */
- (BOOL)addingKeys
{
	BOOL returnBool;

	[addingKeysLock lock];
	returnBool = addingKeys;
	[addingKeysLock unlock];

	return returnBool;
}

/* Returns the SSHKey at Index nr. */
- (SSHKey *)keyAtIndex:(int)nr
{
	SSHKey *returnKey;

	[keychainLock lock];

	if((nr < 0) || (nr > [keychain count]))
	{
		[keychainLock unlock];
		return nil;
	}

	returnKey = [keychain objectAtIndex:nr];
	
	[keychainLock unlock];
	
	return returnKey;
}

/* Remove key from keychain. */
- (BOOL)removeKeyAtIndex:(int)nr
{
	[keychainLock lock];
	[keychain removeObjectAtIndex:nr];
	[keychainLock unlock];

	[[NSNotificationCenter defaultCenter]  postNotificationName:@"KeychainChanged" object:nil];

	return YES;
}

/* Add SSHKey object to keychain. */
- (BOOL)addKey:(SSHKey *)key
{
	[keychainLock lock];
	[keychain addObject:key];
	[keychainLock unlock];

	[[NSNotificationCenter defaultCenter]  postNotificationName:@"KeychainChanged" object:nil];

	return YES;
}

/* Construct SSHKey object and add it to the keychain. */
- (BOOL)addKeyWithPath:(NSString *)path
{
	SSHKey *key = [SSHKey keyWithPath:path];

	if(key == nil)
	{
		return NO;
	}

	[keychainLock lock];
	[keychain addObject:key];
	[keychainLock unlock];

	[[NSNotificationCenter defaultCenter]  postNotificationName:@"KeychainChanged" object:nil];

	return YES;
}

/* Return an array of paths for all keys on the keychain. */
- (NSArray *)arrayOfPaths
{
	NSMutableArray *paths = [NSMutableArray array];
	int i;
	
	[keychainLock lock];

	for(i=0; i < [keychain count]; i++)
	{
		[paths addObject:[[keychain objectAtIndex:i] path]];
	}

	[keychainLock unlock];

	return paths;
}

/* Return the number of keys on the chain. */	
- (int)count
{
	int returnInt = 0;
	
	[keychainLock lock];
	returnInt = [keychain count];
	[keychainLock unlock];

	return returnInt;
}

/* Wrapper for addKeysToAgentWithInteraction:YES. */
- (BOOL)addKeysToAgent
{
	return [self addKeysToAgentWithInteraction:YES];
}

/* Add all keys from the keychain to the ssh-agent. */
- (BOOL)addKeysToAgentWithInteraction:(BOOL)interaction
{
	NSMutableArray *paths;
	SSHTool *theTool;
	int i, ts;

	paths = [[self arrayOfPaths] mutableCopy];

	if([self addingKeys])
	{
		return YES;
	}

	if((!agentSocketPath) || ([[NSFileManager defaultManager] isReadableFileAtPath:agentSocketPath] == NO))
	{
		return NO;
	}
	
	for(i=0; i < [paths count]; i++) {
		if([[NSFileManager defaultManager] isReadableFileAtPath:[paths objectAtIndex:i]] == NO) {
			[paths removeObjectAtIndex:i];
			i--;
		}
	}
		
	if([paths count] < 1)
	{
		return NO;
	}

	[addingKeysLock lock];
	addingKeys = YES;
	[addingKeysLock unlock];
	
	theTool =  [SSHTool toolWithName:@"ssh-add"];

        /* Set the SSH_ASKPASS + DISPLAY environment variables, so the tool can ask for a passphrase. */
	[theTool setEnvironmentVariable:@"SSH_ASKPASS" withValue:
		[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"PassphraseRequester"]];
		
	[theTool setEnvironmentVariable:@"DISPLAY" withValue:@":0"];

	/* If we want user interaction, we set the environment variable so PassphraseRequester knows this. */
	if(interaction)
	{
		[theTool setEnvironmentVariable:@"INTERACTION" withValue:@"1"];
	}

	/* Set the SSH_AUTH_SOCK environment variable so the tool can talk to the real agent. */
	[theTool setEnvironmentVariable:@"SSH_AUTH_SOCK" withValue:agentSocketPath];

	if((paths != nil) && ([paths count] > 0))
	{
		[theTool setArguments:paths];

		if([theTool launchAndWait] == NO)
		{
			[addingKeysLock lock];
			addingKeys = NO;
			[addingKeysLock unlock];
			return NO;
		}
		
		if([[NSUserDefaults standardUserDefaults] integerForKey:KeyTimeoutString] > 0)
		{
			ts = time(nil);
			[lastAddedLock lock];
			lastAdded = ts;
			[lastAddedLock unlock];
			
			[NSThread detachNewThreadSelector:@selector(removeKeysAfterTimeout:) toTarget:self 
									withObject:[NSNumber numberWithInt:ts]];
		}

		[[NSNotificationCenter defaultCenter]  postNotificationName:@"AgentFilled" object:nil];

		[addingKeysLock lock];
		addingKeys = NO;
		[addingKeysLock unlock];
		return YES;
	}
	
	[addingKeysLock lock];
	addingKeys = NO;
	[addingKeysLock unlock];

	return YES;
}

/* Remove all keys from the ssh-agent from a NSTimer object. */
- (void)removeKeysAfterTimeout:(id)object
{
	int ts;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	ts = [object intValue];
	
	sleep([[NSUserDefaults standardUserDefaults] integerForKey:KeyTimeoutString] * 60);
	
	[lastAddedLock lock];
	if(ts == lastAdded) 
	{
		[lastAddedLock unlock];
		[self removeKeysFromAgent];
	}
	
	[lastAddedLock unlock];
	
	[pool release];
}

/* Remove all keys from the ssh-agent. */
- (BOOL)removeKeysFromAgent
{
	SSHTool *theTool = [SSHTool toolWithName:@"ssh-add"];
	
	[lastAddedLock lock];
	lastAdded = -1;
	[lastAddedLock unlock];

	if((!agentSocketPath) || ([[NSFileManager defaultManager] isReadableFileAtPath:agentSocketPath] == NO))
	{
		return NO;
	}

	[theTool setArgument:@"-D"];
	[theTool setEnvironmentVariable:@"SSH_AUTH_SOCK" withValue:agentSocketPath];

	[theTool launchAndWait];

	[[NSNotificationCenter defaultCenter]  postNotificationName:@"AgentEmptied" object:nil];

	return YES;
}

@end
