//
//  TokenController.m
//  SSHKeychain
//
//  Created by Bart Matthaei on 22-8-07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "TokenController.h"

TokenController* sharedTokenController;

@implementation TokenController
- (id)init
{
	if(!(self = [super init]))
	{
		return nil;
	}
	
	tokens = [[NSMutableArray alloc] init];
	tokenLock = [[NSLock alloc] init];
	
	sharedTokenController = self;
	
	return self;
}

- (void)dealloc
{
	[tokens dealloc];
	[tokenLock dealloc];
	
	[super dealloc];
}

+ (TokenController *)sharedController
{
	if(!sharedTokenController) {
		return [[TokenController alloc] init];
	}
	
	return sharedTokenController;
}

- (bool)generateNewTokenForTool:(SSHTool *)tool
{
	NSString *token;
	
	if(tool == nil) return NO;
	
	token = [self generateNewToken];
	
	if(token == nil) return NO;

	[tool setEnvironmentVariable:@"SSHKeychainToken" withValue:token];

	return YES;
}

- (NSString *)generateNewToken
{
	SSHToken *token;
	
	token = [SSHToken randomToken];
	
	if(token != nil)
	{
		[tokenLock lock];
		[tokens addObject:token];
		[tokenLock unlock];
		
		return [token getToken];
	}
	
	return nil;
}

- (bool)checkToken:(NSString *)token
{
	NSEnumerator *e;
	SSHToken *aToken;
	
	[tokenLock lock];

	e = [tokens objectEnumerator];

	while (aToken = [e nextObject])
	{
		if ([[aToken getToken] isEqualTo:token])
		{
			if([aToken isValid])
			{
				[tokens removeObject:aToken];
				[tokenLock unlock];
				return YES;
			}
			
			[tokens removeObject:aToken];
		} else if(![aToken isValid]) {
			[tokens removeObject:aToken];
		}
	}
	
	[tokenLock unlock];
	
	return NO;
}

@end
