#import "PreferenceView.h"

@interface TunnelsView : PreferenceView
{
	IBOutlet id tunnelTable, delTunnelButton;
	IBOutlet id tunnelDetailsView;

	IBOutlet id tunnelName, tunnelCompression;
	IBOutlet id tunnelHostname, tunnelPort, tunnelUser;
	IBOutlet id tunnelLaunchOnAgentFilled, tunnelLaunchAfterSleep;
	
	IBOutlet id localPortForwardTable, remotePortForwardTable, delLocalPortForwardButton, delRemotePortForwardButton;

	NSMutableArray *tunnels;

	NSMutableArray *localPortForwards;
	NSMutableArray *remotePortForwards;
	
	int tunnelIndex;
}

- (IBAction)addTunnel:(id)sender;
- (IBAction)delTunnel:(id)sender;

- (IBAction)addLocalPortForward:(id)sender;
- (IBAction)delLocalPortForward:(id)sender;
- (IBAction)addRemotePortForward:(id)sender;
- (IBAction)delRemotePortForward:(id)sender;

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
