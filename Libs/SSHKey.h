#import <Foundation/Foundation.h>

#define RSA1 1
#define RSA 2
#define DSA 3

@interface SSHKey : NSObject 
{
	NSString *fullpath;
	int type;
}

+ (id)keyWithPath:(NSString *)fullpath;

- (int)type;
- (NSString *)typeAsString;
- (NSString *)path;

@end
