#import "SSHKey.h"

@implementation SSHKey

/* Construct a SSHKey object with thePath as private key. */
+ (id)keyWithPath:(NSString *)thePath
{
	thePath = [thePath stringByExpandingTildeInPath];

	return [[[self alloc] initWithPath:thePath] autorelease];
}

+ (SSHKeyType) typeOfKeyAtPath:(NSString *)thePath
{
	/* Read the file and determine what type we're working with. */
	NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:thePath];
	NSArray *lines = [[[[NSString alloc] initWithData:[handle availableData] encoding:NSUTF8StringEncoding] autorelease] componentsSeparatedByString:@"\n"];

	if ([[lines objectAtIndex:0] isEqualToString:@"SSH PRIVATE KEY FILE FORMAT 1.1"])
		return SSH_KEYTYPE_RSA1;
	else if ([[lines objectAtIndex:0] isEqualToString:@"-----BEGIN RSA PRIVATE KEY-----"])
		return SSH_KEYTYPE_RSA;
	else if ([[lines objectAtIndex:0] isEqualToString:@"-----BEGIN DSA PRIVATE KEY-----"])
		return SSH_KEYTYPE_DSA;
	else
		return SSH_KEYTYPE_UNKNOWN;
}

- (id)initWithPath:(NSString *)thePath
{

	if (!(self = [super init]))
		return nil;

	fullPath = [thePath copy];
	type = [[self class] typeOfKeyAtPath:thePath];

	return self;
}

- (void) dealloc
{
	[fullPath release];
	[super dealloc];
}

/* Return the type of the private key as integer. */
- (SSHKeyType)type
{
	return type;
}

/* Return the type of the private key as NSString. */
- (NSString *)typeAsString
{
	switch (type)
	{
		case SSH_KEYTYPE_RSA1:
			return @"RSA1";
		case SSH_KEYTYPE_RSA:
			return @"RSA";
		case SSH_KEYTYPE_DSA:
			return @"DSA";
		case SSH_KEYTYPE_UNKNOWN:
			return nil;
	}
	return nil;
}

/* Return the path of the private key. */
- (NSString *)path
{
	return [[fullPath copy] autorelease];
}

@end
