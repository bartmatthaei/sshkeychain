#import <Foundation/Foundation.h>
#import <Security/Security.h>

@interface TunnelController : NSObject {
	
	/* Tunnels Menu Item. */
	IBOutlet id mainMenuTunnelsItem, dockMenuTunnelsItem, statusbarMenuTunnelsItem;
	
	NSMutableArray *tunnels;
	
	BOOL allKeysOnAgent;

	/* Threaded notification support */
	NSMutableArray *notificationQueue;
	NSThread *notificationThread;
	NSLock *notificationLock;
	NSMachPort *notificationPort;
}

+ (TunnelController *)sharedController;

- (void)sync;
- (void)changeTunnelName:(NSString *)oldName toName:(NSString *)newName;
- (void)removeTunnelWithName:(NSString *)name;

- (void)setToolTipForActiveTunnels;

- (void)closeAllTunnels;
- (void)launchAfterSleepTunnels;

- (IBAction)toggleTunnel:(id)sender;

- (void)openTunnelWithDict:(NSMutableDictionary *)dict;

- (void)warningPanelWithTitle:(NSString *)title andMessage:(NSString *)message;

- (void)handleMachMessage:(void *)msg;

@end
