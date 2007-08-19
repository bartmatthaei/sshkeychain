#import <Foundation/Foundation.h>

typedef enum
{
	SSH_KEYTYPE_UNKNOWN = 0,
	SSH_KEYTYPE_RSA1 = 1,
	SSH_KEYTYPE_RSA = 2,
	SSH_KEYTYPE_DSA = 3
} SSHKeyType;

@interface SSHKey : NSObject 
{
	NSString *fullPath;
	SSHKeyType type;
}

+ (id)keyWithPath:(NSString *)fullpath;

- (SSHKeyType)type;
- (NSString *)typeAsString;
- (NSString *)path;

@end
