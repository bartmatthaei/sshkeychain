#import "EnvironmentView.h"

#import "PreferenceController.h"

@implementation EnvironmentView

- (void)loadPreferences
{
	NSString *path;

	path = [[NSString stringWithString:@"~/.MacOSX/environment.plist"] stringByExpandingTildeInPath];

	environment = [[[NSMutableDictionary alloc] initWithContentsOfFile:path] autorelease];
	if(environment == NULL)
	{
		environment = [NSMutableDictionary dictionary];
	}

	[environment retain];

	/* Put all the environment variable names and put them into the environmentKeys array. */
	environmentKeys = [[NSMutableArray arrayWithArray:[environment allKeys]] retain];
	[environmentKeys retain];

	[manageGlobalEnvironment setState:[[NSUserDefaults standardUserDefaults] boolForKey:manageGlobalEnvironmentString]];

	if([[NSUserDefaults standardUserDefaults] boolForKey:manageGlobalEnvironmentString]) 
	{
		NSSize environmentSize = [environmentTableView frame].size;
		environmentSize.width = [self viewSize].width;
		[environmentTableView setFrameSize:environmentSize];
		[view addSubview:environmentTableView];
	}
	
	[environmentTable setDataSource:self];
}

- (NSSize)viewSize
{
	NSSize size = [view frame].size;

	if([[NSUserDefaults standardUserDefaults] boolForKey:manageGlobalEnvironmentString])
	{
		size.height = (54 + [environmentTableView frame].size.height);
	}

	else
	{
		size.height = 54;
	}

	return size;
}

/* When the manageGlobalEnvironment option is toggled, add the SSH_AUTH_SOCK and CVS_RSH variable to the global environment. */
- (IBAction)toggleManageGlobalEnvironment:(id)sender
{
	NSUserDefaults *prefs;

	prefs = [NSUserDefaults standardUserDefaults];
	[prefs setBool:[sender state] forKey:manageGlobalEnvironmentString];
	[prefs synchronize];

	if([sender state] == YES)
	{
		if(![environment objectForKey:@"CVS_RSH"]) {
			[environment setObject:@"ssh" forKey:@"CVS_RSH"];
		}

		[environment setObject:[[NSUserDefaults standardUserDefaults] stringForKey:socketPathString] forKey:@"SSH_AUTH_SOCK"];

		[self syncEnvironment];

		[[PreferenceController sharedController] resizeWindowToSize:[self viewSize]];
		NSSize environmentSize = [environmentTableView frame].size;
		environmentSize.width = [self viewSize].width;
		[environmentTableView setFrameSize:environmentSize];
		[view addSubview:environmentTableView];
	}

	else if([sender state] == NO)
	{
		[environment removeObjectForKey:@"SSH_AUTH_SOCK"];

		[self syncEnvironment];

		[environmentTableView removeFromSuperview];
		[[PreferenceController sharedController] resizeWindowToSize:[self viewSize]];
	}
}

/* Add an environment variable. */
- (IBAction)addEnvironmentVariable:(id)sender
{
	if(![environmentKeys containsObject:@"newVariable"])
	{
		[environment setObject:@"" forKey:@"newVariable"];
		[self syncEnvironment];
	}
}

/* Delete an environment variable. */
- (IBAction)delEnvironmentVariable:(id)sender
{
	NSString *variable = [environmentKeys objectAtIndex:[environmentTable selectedRow]];

	if([environmentTable selectedRow] < 0)
	{
		return;
	}

	/* We don't want users removing the SSH_AUTH_SOCK variable when the userGlobalEnvironment option is on. */
	if(![variable isEqualToString:@"SSH_AUTH_SOCK"])
	{
		[environment removeObjectForKey:variable];
		[self syncEnvironment];
	}
}

/* Update the UI. */
- (void)updateUI
{
	NSString *variable;
	
	/* If the user selected an environment variable, enable the delEnvironmentVariableButton. */
	if(([environmentTable selectedRow] != -1) && ([environmentKeys count] > 0))
	{
		variable = [environmentKeys objectAtIndex:[environmentTable selectedRow]];

		/* If the user selected the SSH_AUTH_SOCK environment variable, disable the delEnvironmentVariableButton. */
		if(![variable isEqualToString:@"SSH_AUTH_SOCK"])
		{
			[delEnvironmentVariableButton setEnabled:YES];
		}

		else
		{
			[delEnvironmentVariableButton setEnabled:NO];
		}
	}

	else
	{
		[delEnvironmentVariableButton setEnabled:NO];
	}
	
	[environmentTable reloadData];
}

/* Write the environment to ~/.MacOSX/environment.plist. */
- (void)syncEnvironment
{
	NSString *path, *dir;
	BOOL isDirectory;

	path = [[NSString stringWithString:@"~/.MacOSX/environment.plist"] stringByExpandingTildeInPath];
	dir = [[NSString stringWithString:@"~/.MacOSX"] stringByExpandingTildeInPath];
	
	/* If ~/.MacOSX/ doesn't exists, create a directory. */
	if(![[NSFileManager defaultManager] fileExistsAtPath:dir isDirectory:&isDirectory])
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:dir attributes:nil];
	}

	/* If ~/.MacOSX is a file, instead of a directory, remove it and create a directory. */
	else if(isDirectory == NO)
	{
		[[NSFileManager defaultManager] removeFileAtPath:dir handler:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:dir attributes:nil];
	}		

	[environment writeToFile:path atomically:YES];
	
	if(environmentKeys)
	{
		[environmentKeys release];
	}

	environmentKeys = [[NSMutableArray arrayWithArray:[environment allKeys]] retain];
	[environmentKeys retain];

	[self updateUI];
}

/* Delegated methods from NSTableView. */


- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
	[self updateUI];
}

- (int)numberOfRowsInTableView:(NSTableView *)table
{
	return [environmentKeys count];
}

- (id)tableView:(NSTableView *)table objectValueForTableColumn:(NSTableColumn *)column row:(int)nr
{
	if([[column identifier] isEqualToString:@"variable"])
	{
		return [environmentKeys objectAtIndex:nr];
	}

	else if([[column identifier] isEqualToString:@"value"])
	{
		return [environment objectForKey:[environmentKeys objectAtIndex:nr]];
	}

	return NULL;
}

- (void)tableView:(NSTableView *)table setObjectValue:(id)object forTableColumn:(NSTableColumn *)column row:(int)row
{
	NSString *tmp;
	
	if(!object)
	{
		return;
	}
	
	if([[column identifier] isEqualToString:@"variable"])
	{
		if([environmentKeys containsObject:object])
		{
			return;
		}

		tmp = [environment objectForKey:[environmentKeys objectAtIndex:row]];
		if(!tmp)
		{
			tmp = @"";
		}
		
		[environment setObject:tmp forKey:object];
		
		[environment removeObjectForKey:[environmentKeys objectAtIndex:row]];

		[self syncEnvironment];
	}

	else if([[column identifier] isEqualToString:@"value"])
	{
		if([[environment objectForKey:[environmentKeys objectAtIndex:row]] isEqualToString:object])
		{
			return;
		}

		[environment setObject:object forKey:[environmentKeys objectAtIndex:row]];

		[environmentTable deselectAll:self];
		
		[self syncEnvironment];
	}
}

- (BOOL)tableView:(NSTableView *)table shouldEditTableColumn:(NSTableColumn *)column row:(int)row
{
	if([[environmentKeys objectAtIndex:row] isEqualToString:@"SSH_AUTH_SOCK"])
	{
		return NO;
	}

	return YES;
}

@end
