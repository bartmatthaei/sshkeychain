#import "PreferenceView.h"

@interface EnvironmentView : PreferenceView
{
	/* Environment view */
	IBOutlet id manageGlobalEnvironment, environmentTable, delEnvironmentVariableButton, environmentTableView;

	NSMutableDictionary *environment;
	NSMutableArray *environmentKeys;
}

- (IBAction)toggleManageGlobalEnvironment:(id)sender;
- (IBAction)addEnvironmentVariable:(id)sender;
- (IBAction)delEnvironmentVariable:(id)sender;

- (void)updateUI;
- (void)syncEnvironment;

/* Delegates from NSTableView. */
- (void)tableViewSelectionDidChange:(NSNotification *)notification;
- (int)numberOfRowsInTableView:(NSTableView *)table;
- (id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(int)nr;
- (BOOL)tableView:(NSTableView *)table shouldEditTableColumn:(NSTableColumn *)column row:(int)row;

@end
