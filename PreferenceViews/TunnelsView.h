#import "PreferenceView.h"

@interface TunnelsView : PreferenceView
{
	IBOutlet id tunnelTable, delTunnelButton;
	IBOutlet id tunnelDetailsView;
	IBOutlet NSTabView *tunnelDetailsTabView;

	IBOutlet id tunnelName, tunnelCompression, tunnelRemoteAccess;
	IBOutlet id tunnelHostname, tunnelPort, tunnelUser;
	IBOutlet id tunnelLaunchOnAgentFilled, tunnelLaunchAfterSleep;
	
	IBOutlet id localPortForwardTable, remotePortForwardTable, dynamicPortForwardTable;
	IBOutlet id delLocalPortForwardButton, delRemotePortForwardButton, delDynamicPortForwardButton;

	NSMutableArray *tunnels;

	NSMutableArray *localPortForwards;
	NSMutableArray *remotePortForwards;
	NSMutableArray *dynamicPortForwards;
	
	int tunnelIndex;
}

- (IBAction)addTunnel:(id)sender;
- (IBAction)delTunnel:(id)sender;

- (IBAction)addLocalPortForward:(id)sender;
- (IBAction)delLocalPortForward:(id)sender;
- (IBAction)addRemotePortForward:(id)sender;
- (IBAction)delRemotePortForward:(id)sender;
- (IBAction)addDynamicPortForward:(id)sender;
- (IBAction)delDynamicPortForward:(id)sender;

- (void)showTunnelDetails:(int)index;
- (void)hideTunnelDetails;
- (void)saveTunnelDetails;

- (void)updateUI;

/* Delegates from NSTableView. */
- (void)tableViewSelectionDidChange:(NSNotification *)notification;
- (int)numberOfRowsInTableView:(NSTableView *)table;
- (id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(int)nr;
- (BOOL)tableView:(NSTableView *)table shouldEditTableColumn:(NSTableColumn *)column row:(int)row;

@end
