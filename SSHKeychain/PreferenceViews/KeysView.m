#import "KeysView.h"

#import "PreferenceController.h"

@implementation KeysView

- (void)loadPreferences
{
	/* Get the current keychain. */
	keychain = [SSHKeychain currentKeychain];

	[keyTable setDataSource:self];
}

/* Add a key to the keychain. */
- (IBAction)addKey:(id)sender
{
	NSOpenPanel *openPanel;
	NSUserDefaults *prefs;
	NSString *path, *dir;
	NSArray *paths;
	SSHKey *key;
	int returnCode, i;

	openPanel = [NSOpenPanel openPanel];
	dir = [NSString stringWithString:@"~/.ssh/"];
	
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setCanChooseDirectories:NO];

	returnCode = [openPanel runModalForDirectory:[dir stringByExpandingTildeInPath] file:nil types:nil];
	
	if(returnCode == NSCancelButton)
	{
		return;
	}

	/* Get the path of the key we need to add. */
	path = [[openPanel filenames] objectAtIndex:0];

	/* Get a list of current paths on the chain so we can check for duplicates. */
	paths = [keychain arrayOfPaths];

	for(i = 0; i < [paths count]; i++)
	{
		/* If we've found a duplicate, warn the user. */
		if([[paths objectAtIndex:i] isEqualToString:path])
		{		
			[self warningPanelWithTitle:local(@"InvalidKey") andMessage:local(@"KeyAlreadyOnList")];
			return;
		}
	}

	NSLog(path);
	
	/* If the key isn't readable, warn the user. */
	if([[NSFileManager defaultManager] isReadableFileAtPath:path] == NO)
	{
		[self warningPanelWithTitle:local(@"InvalidKey") andMessage:local(@"ReadPermissionToKeyDenied")];
		return;
	}

	else {
		key = [SSHKey keyWithPath:path];
		int type = [key type];

		/* If we can't get a decent type, warn the user. */
		if(type == 0)
		{
			[self warningPanelWithTitle:local(@"InvalidKey") andMessage:local(@"InvalidPrivateKey")];
			return;
		}
	}

	[keychain addKey:key];
	paths = [keychain arrayOfPaths];

	if(paths != NULL)
	{
		prefs = [NSUserDefaults standardUserDefaults];
		[prefs setObject:paths forKey:@"Keys"];
		[prefs synchronize];
	}
	
	[self updateUI];
}

/* Delete a key from the chain. */
- (IBAction)delKey:(id)sender
{
	NSArray *paths;
	NSUserDefaults *prefs;
	int nr = [keyTable selectedRow];

	if(nr > -1)
	{
		[keychain removeKeyAtIndex:nr];
		/* Get a new list of paths. */
		paths = [keychain arrayOfPaths];
		if(paths != NULL)
		{
			/* Write the paths to the UserDefaults. */
			prefs = [NSUserDefaults standardUserDefaults];
			[prefs setObject:paths forKey:@"Keys"];
			[prefs synchronize];
		}

		[self updateUI];
	}
}

/* Show New Key View. */
- (IBAction)newKey:(id)sender
{
	[newKeyPath setStringValue:@""];
	[newKeyType selectItemAtIndex:0];
	[newKeyBits selectItemAtIndex:1];
	
	[newKeyProgressText setTextColor:[NSColor blackColor]];
	[newKeyProgressText setStringValue:@""];
	
	[newKeyType setEnabled:NO];
	[newKeyBits setEnabled:NO];
	[newKeyPassphrase setEnabled:NO];
	[newKeyGenerateButton setEnabled:NO];

	[[[PreferenceController preferenceController] window] setContentView:[[[NSView alloc] init] autorelease]];
	[[PreferenceController preferenceController] resizeWindowToSize:[newKeyView frame].size];
	[[[PreferenceController preferenceController] window] setContentView:newKeyView];
}

/* Cancel New Key View. */
- (IBAction)cancelNewKey:(id)sender
{
	[[[PreferenceController preferenceController] window] setContentView:[[[NSView alloc] init] autorelease]];
	[[PreferenceController preferenceController] resizeWindowToSize:[view frame].size];
	[[[PreferenceController preferenceController] window] setContentView:view];
}

/* Generate new keypair. */
- (IBAction)generateNewKey:(id)sender
{
	NSString *path, *passphrase, *type, *bits;
	NSArray *paths;
	NSUserDefaults *prefs;
	SSHKey *key;
	SSHTool *theTool = [SSHTool toolWithName:@"ssh-keygen"];

	path = [newKeyPath stringValue];
	passphrase = [NSString stringWithString:[newKeyPassphrase stringValue]];
	
	/* Clear the passphrase field. */
	[newKeyPassphrase setStringValue:@""];
	
	/* If the user didn't specify a path, warn. */
	if([path isEqualToString:@""])
	{
		[newKeyProgressText setTextColor:[NSColor redColor]];
		[newKeyProgressText setStringValue:[NSString stringWithFormat:local(@"PleaseSelectAPath"), path]];
		return;
	}
	
	/* If the file already exists (which shouldn't happen), warn. */
	if([[NSFileManager defaultManager] fileExistsAtPath:path] == YES)
	{
		[newKeyProgressText setTextColor:[NSColor redColor]];
		[newKeyProgressText setStringValue:[NSString stringWithFormat:@"%@ %@", path, local(@"AlreadyExists")]];
		[newKeyPath setStringValue:@""];
		return;
	}
	
	/* Check fit he key type is valid. */
	switch([[newKeyType selectedItem] tag])
	{
		case(1):
			type = @"dsa";
			break;
		case(2):
			type = @"rsa";
			break;
		case(3):
			type = @"rsa1";
			break;
		default:
			[newKeyProgressText setTextColor:[NSColor redColor]];
			[newKeyProgressText setStringValue:local(@"KeyTypeUnknown")];
			return;
	}
	
	/* Check if the nr. of bits are valid. */
	switch([[newKeyBits selectedItem] tag])
	{
		case(1):
			bits = @"512";
			break;
		case(2):
			bits = @"1024";
			break;
		case(3):
			bits = @"2048";
			break;
		default:
			[newKeyProgressText setTextColor:[NSColor redColor]];
			[newKeyProgressText setStringValue:local(@"NumberOfBitsInvalid")];
			return;
	}
	
	/* Check if the passphrase is long enough. */
	if([passphrase length] < 5)
	{
		[newKeyProgressText setTextColor:[NSColor redColor]];
		[newKeyProgressText setStringValue:local(@"PassphraseTooShort")];
		return;
	}

	[newKeyType setEnabled:NO];
	[newKeyBits setEnabled:NO];
	[newKeyPassphrase setEnabled:NO];
	[newKeyGenerateButton setEnabled:NO];

	/* Start the animation. */
	[newKeyProgress displayIfNeeded];
	[newKeyProgress startAnimation:self];
	[newKeyProgressText setTextColor:[NSColor blackColor]];
	[newKeyProgressText setStringValue:local(@"Generating")];

	[theTool setArguments:
		[NSArray arrayWithObjects:@"-q", @"-t", type, @"-b", bits, @"-f", path, @"-N", passphrase, nil]
	];

	/* Generate the key. */
	if([theTool launchAndWait] == NO)
	{
		[newKeyProgress stopAnimation:self];
		[newKeyProgressText setTextColor:[NSColor redColor]];
		[newKeyProgressText setStringValue:local(@"KeyGenerationFailed")];

		[newKeyType setEnabled:YES];
		[newKeyBits setEnabled:YES];
		[newKeyPassphrase setEnabled:YES];
		[newKeyGenerateButton setEnabled:YES];

		return;
	}
	
	[newKeyProgress stopAnimation:self];

	[newKeyType setEnabled:YES];
	[newKeyBits setEnabled:YES];
	[newKeyPassphrase setEnabled:YES];
	[newKeyGenerateButton setEnabled:YES];
	
        if([[NSFileManager defaultManager] isReadableFileAtPath:path] == NO)
	{
		[newKeyProgressText setTextColor:[NSColor redColor]];
		[newKeyProgressText setStringValue:local(@"ReadPermissionToKeyDenied")];

		return;
	}

	[newKeyProgressText setStringValue:@"Done"];
	
	key = [SSHKey keyWithPath:path];
	
	/* If we can't get a decent type, warn the user. */
	if([key type] == 0)
	{
		[self warningPanelWithTitle:local(@"InvalidKey") andMessage:local(@"InvalidPrivateKey")];

		return;
	}

	/* Add the key to the keychain. */
	[keychain addKey:key];
	paths = [keychain arrayOfPaths];

	if(paths != NULL)
	{
		prefs = [NSUserDefaults standardUserDefaults];
		[prefs setObject:paths forKey:@"Keys"];
		[prefs synchronize];
	}

	[self updateUI];

	[[[PreferenceController preferenceController] window] setContentView:[[[NSView alloc] init] autorelease]];
	[[PreferenceController preferenceController] resizeWindowToSize:[view frame].size];
	[[[PreferenceController preferenceController] window] setContentView:view];
}

/* Ask the user where we should save the key. */
- (IBAction)selectNewKeyPath:(id)sender
{
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	int returnCode;
	
	[savePanel setMessage:local(@"WhereWouldYouLikeToSaveThePrivateKey")];
	[savePanel setDelegate:self];
	
	returnCode = [savePanel runModalForDirectory:@"~/.ssh" file:nil];
	
	if(returnCode == NSFileHandlingPanelCancelButton)
	{
		return;
	}
	
	if([savePanel filename])
	{
		[newKeyPath setStringValue:[savePanel filename]];
		
		[newKeyType setEnabled:YES];
		[newKeyBits setEnabled:YES];
		[newKeyPassphrase setEnabled:YES];
		[newKeyGenerateButton setEnabled:YES];
	}
}

/* Update the UI. */
- (void)updateUI
{
	/* If the user selected a key, enable the delKeyButton. */
	if(([keyTable selectedRow] != -1) && ([keychain count] > 0))
	{
		[delKeyButton setEnabled:YES];
	}

	else
	{
		[delKeyButton setEnabled:NO];
	}

	[keyTable reloadData];
}

/* Delegated methods from NSSavePanel. */

- (NSString *)panel:(id)sender userEnteredFilename:(NSString *)filename confirmed:(BOOL)okFlag
{       
	if((okFlag == YES) && ([[NSFileManager defaultManager] fileExistsAtPath:[sender filename]]))
	{
		return NULL;
	}
	
	return filename;
}

/* Delegated methods from NSTableView. */

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	[self updateUI];
}

- (int)numberOfRowsInTableView:(NSTableView *)table
{
	if(keychain)
	{
		return [keychain count];
	}

	return 0;
}

- (id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(int)nr
{
	if((keychain) && (nr < [keychain count]))
	{
		if([[column identifier] isEqualToString:@"location"])
		{
			return [[keychain keyAtIndex:nr] path];
		}

		else if([[column identifier] isEqualToString:@"type"])
		{
			return [[keychain keyAtIndex:nr] typeAsString];
		}
	}
	
	return NULL;
}

- (BOOL)tableView:(NSTableView *)table shouldEditTableColumn:(NSTableColumn *)column row:(int)row
{
	return NO;
}

@end
