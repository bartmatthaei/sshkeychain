/* $Id: AgentController.h,v 1.9 2004/06/23 08:12:20 bart Exp $ */

#import <Cocoa/Cocoa.h>
#import <Security/Security.h>

#import "Libs/SSHAgent.h"
#import "Libs/SSHKeychain.h"

@interface AgentController : NSObject
{
	IBOutlet id agentStatusWindow, keyTable, delKeyButton;
	IBOutlet id agentPID, agentGlobalAuthSocket, agentLocalAuthSocket;
	IBOutlet id mainMenuAgentItem, dockMenuAgentItem, statusbarMenuAgentItem;
	IBOutlet id mainMenuRemoveKeysItem, dockMenuRemoveKeysItem, statusbarMenuRemoveKeysItem;
	IBOutlet id mainMenuAddKeysItem, dockMenuAddKeysItem, statusbarMenuAddKeysItem;
	IBOutlet id mainMenuAddKeyItem, dockMenuAddKeyItem, statusbarMenuAddKeyItem;

	SSHAgent *agent;
	SSHKeychain *keychain;

	int timestamp;

	BOOL allKeysOnAgent;

	/* Locks */
	NSLock *allKeysOnAgentLock;
}

- (IBAction)toggleAgent:(id)sender;
- (IBAction)addKeysToAgent:(id)sender;
- (IBAction)addSingleKeyToAgent:(id)sender;
- (IBAction)removeKeysFromAgent:(id)sender;

- (IBAction)showAgentStatusWindow:(id)sender;
- (void)updateUI;

- (BOOL)checkSocketPath:(NSString *)path;
- (void)warningPanelWithTitle:(NSString *)title andMessage:(NSString *)message;
- (void)warningPanelWithTitle:(NSString *)title andMessage:(NSString *)message inMainThread:(BOOL)thread;

@end
