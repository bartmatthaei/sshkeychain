#import "PreferenceView.h"

#import "SSHKeychain.h"
#import "SSHTool.h"

@interface KeysView : PreferenceView
{
	/* Keys. */
	IBOutlet id keyTable, delKeyButton;

	/* Generate Key View */
	IBOutlet id newKeyView, newKeyPath, newKeyType, newKeyBits, newKeyProgress, newKeyProgressText;
	IBOutlet id newKeyPassphrase, newKeyGenerateButton;

	SSHKeychain *keychain;
}

- (IBAction)addKey:(id)sender;
- (IBAction)delKey:(id)sender;
- (IBAction)newKey:(id)sender;

- (IBAction)generateNewKey:(id)sender;
- (IBAction)cancelNewKey:(id)sender;
- (IBAction)selectNewKeyPath:(id)sender;
- (void)updateUI;

/* Delegates from NSSavePanel. */
- (NSString *)panel:(id)sender userEnteredFilename:(NSString *)filename confirmed:(BOOL)okFlag;

/* Delegates from NSTableView. */
- (void)tableViewSelectionDidChange:(NSNotification *)notification;
- (int)numberOfRowsInTableView:(NSTableView *)table;
- (id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(int)nr;
- (BOOL)tableView:(NSTableView *)table shouldEditTableColumn:(NSTableColumn *)column row:(int)row;

@end
