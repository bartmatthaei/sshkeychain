#import "SSHKey.h"

@implementation SSHKey

/* Construct a SSHKey object with thePath as private key. */
+ (id)keyWithPath:(NSString *)thePath
{
	thePath = [thePath stringByExpandingTildeInPath];

	return [[[self alloc] initWithPath:thePath] autorelease];
}

- (id)initWithPath:(NSString *)thePath
{
	NSFileHandle *handle;
	NSArray *lines;

	if((self = [super init]) == NULL)
	{
		return NULL;
	}

	fullpath = [[NSString stringWithString:thePath] retain];

	/* Read the file and determine what type we're working with. */
	handle = [NSFileHandle fileHandleForReadingAtPath:fullpath];
	lines = [[[[NSString alloc] initWithData:[handle availableData] encoding:NSASCIIStringEncoding] autorelease] componentsSeparatedByString:@"\n"];

	if([[lines objectAtIndex:0] isEqualToString:@"SSH PRIVATE KEY FILE FORMAT 1.1"])
		type = RSA1;
	else if([[lines objectAtIndex:0] isEqualToString:@"-----BEGIN RSA PRIVATE KEY-----"])
		type = RSA;
	else if([[lines objectAtIndex:0] isEqualToString:@"-----BEGIN DSA PRIVATE KEY-----"])
		type = DSA;
	else
		type = 0;

	return self;
}

/* Return the type of the private key as integer. */
- (int)type
{
	return type;
}

/* Return the type of the private key as NSString. */
- (NSString *)typeAsString
{
	if(type == RSA1) {
		return @"RSA1";
	}

	else if(type == RSA)
	{
		return @"RSA";
	}

	else if(type == DSA)
	{
		return @"DSA";
	}

	else
	{
		return NULL;
	}
}

/* Return the path of the private key. */
- (NSString *)path
{
	return fullpath;
}

@end
