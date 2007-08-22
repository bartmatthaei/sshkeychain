#import "SSHToken.h"

#include <fcntl.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <string.h>

@implementation SSHToken

+ (id)randomToken
{
        int fd, r, i, c;
        char final[100];
        char *buf;
	
        final[0] = 0;
	
        fd = open("/dev/urandom", O_RDONLY, 0);
	
        if(fd == -1) {
		return nil;
        }
	
        while(strlen(final) < 99) {
                buf = final + strlen(final);
                if((r = read(fd, buf, 99 - strlen(final))) < 1) {
                        return nil;
                }
                buf[r] = 0;
        }
	
        for(i=0; i < strlen(final); i++) {
                c = final[i];
		
                if(c < 0) c = c * -1;
                if(c > 126) c = c / 2;
                if(c < 33) c += 33;
		
                final[i] = c;
        }
	
	SSHToken *token = [[[self alloc] init] autorelease];
	
	[token setToken:[NSString stringWithCString:final]];
	
	close(fd);
		
	return token;
}

- (id)init
{
	if (! (self = [super init]))
		return nil;
	
	timestamp = time(0);
	
	return self;
}

- (void)setToken:(NSString *)string
{
	token = [string copy];
}

- (NSString *)getToken
{
	return token;
}

- (bool)isValid
{
	if(time(0) - timestamp < 5) {
		return true;
	}
	
	return false;
}

@end
