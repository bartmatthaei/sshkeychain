#import <Foundation/Foundation.h>

#import "SSHTool.h"

@interface SSHTunnel : NSObject 
{
	int tunnelPort;

	NSString *tunnelHost;
	NSString *tunnelUser;

	BOOL compression;
	BOOL remoteAccess;

	NSMutableArray *localPortForwards;
	NSMutableArray *remotePortForwards;
	NSMutableArray *dynamicPortForwards;

	SSHTool *tunnel;
	BOOL open;
	
	NSPipe *thePipe;
	
	SEL closeSelector;
	id closeObject;
	id closeInfo;
}

- (BOOL)setTunnelHost:(NSString *)host withPort:(int)port andUser:(NSString *)user;
- (BOOL)setCompression:(BOOL)theBool;
- (BOOL)setRemoteAccess:(BOOL)theBool;

- (BOOL)addLocalPortForwardWithPort:(int)lport remoteHost:(NSString *)rhost remotePort:(int)rport;
- (BOOL)addRemotePortForwardWithPort:(int)rport localHost:(NSString *)lhost localPort:(int)lport;
- (BOOL)addDynamicPortForwardWithPort:(int)lport;

- (void)handleClosedWithSelector:(SEL)theSelector toObject:(id)theObject withInfo:(id)theInfo;

- (BOOL)isOpen;
- (NSString *)getOutput;

- (BOOL)openTunnel;
- (void)closeTunnel;

@end
