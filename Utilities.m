//
//  Utilities.m
//  SSHKeychain
//
//  Created by Kevin Ballard on 12/8/04.
//  Copyright 2004 Kevin Ballard. All rights reserved.
//

#import "Utilities.h"
#import <CoreFoundation/CoreFoundation.h>

NSString *CreateUUID()
{
	CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
	CFStringRef uuidStr = CFUUIDCreateString(kCFAllocatorDefault, uuid);
	CFRelease(uuid);
	NSString *result = [(NSString *)uuidStr autorelease];
	return result;
}
