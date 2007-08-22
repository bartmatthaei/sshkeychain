#import <Cocoa/Cocoa.h>

@interface SSHToken : NSObject {
	int timestamp;
	NSString *token;
}

+ (id)randomToken;

- (void)setToken:(NSString *)string;
- (NSString *)getToken;
- (bool)isValid;

@end
