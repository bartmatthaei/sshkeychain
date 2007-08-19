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
