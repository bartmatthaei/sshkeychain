#import <Foundation/Foundation.h>

#import "SSHTool.h"

@interface SSHTunnel : NSObject 
{
	int tunnelPort;

	NSString *tunnelHost;
	NSString *tunnelUser;

	BOOL compression;

	NSMutableArray *localPortForwards;
	NSMutableArray *remotePortForwards;

	SSHTool *tunnel;
	BOOL open;
	
	NSPipe *thePipe;
	
	SEL closeSelector;
	id closeObject;
	id closeInfo;
}

- (BOOL)setTunnelHost:(NSString *)host withPort:(int)port andUser:(NSString *)user;
- (BOOL)setCompression:(BOOL)theBool;

- (BOOL)addLocalPortForwardWithPort:(int)lport remoteHost:(NSString *)lhost remotePort:(int)rport;
- (BOOL)addRemotePortForwardWithPort:(int)rport localHost:(NSString *)lhost localPort:(int)lport;

- (void)handleClosedWithSelector:(SEL)theSelector toObject:(id)theObject withInfo:(id)theInfo;

- (BOOL)isOpen;
- (NSString *)getOutput;

- (BOOL)openTunnel;
- (void)closeTunnel;

@end
