#import "PreferenceController.h"

NSString *SSHToolsPathString = @"SSH Tools Path";
NSString *SocketPathString = @"Authentication Socket Path";
NSString *DisplayString = @"Display";
NSString *AddKeysOnConnectionString = @"Add Keys On Connection";
NSString *AskForConfirmationString = @"Ask for Confirmation";
NSString *OnSleepString = @"On Sleep";
NSString *OnScreensaverString = @"On Screensaver";
NSString *FollowKeychainString = @"Follow Keychain";
NSString *MinutesOfSleepString = @"Minutes of Sleep";
NSString *ManageGlobalEnvironmentString = @"Manage Global Environment";
NSString *CheckForUpdatesOnStartupString = @"Check For Updates On Startup";
NSString *TunnelsString = @"Tunnels";
NSString *UseGlobalEnvironmentString = @"Use Global Environment ~/.MacOSX/environment.plist";
NSString *UseCustomSecuritySettingsString = @"Use Custom Security Settings";
NSString *CheckScreensaverIntervalString = @"Check Screensaver Interval";
NSString *KeyTimeoutString = @"Key Timeout";
/* Growl support */
NSString *UseGrowlString = @"Use Growl";
NSString *DisableDialogNotificationsWhenUsingGrowlString = @"Disable Dialog Notifications When Using Growl";


PreferenceController *sharedPreferenceController = nil;

@implementation PreferenceController


+ (PreferenceController *)sharedController
{
	if(!sharedPreferenceController) {
		return [[PreferenceController alloc] init];
	}
	
	return sharedPreferenceController;
}

+ (void)openPreferencesWindow
{
	PreferenceController *preferenceController = [PreferenceController sharedController];
	
	if(preferenceController) 
	{
		[NSApp activateIgnoringOtherApps:YES];
		[preferenceController showWindow];
	}
}

#pragma mark -

- (id)init
{
	if(self = [super init])
	{
		sharedPreferenceController = self;

		blankView = [[NSView alloc] init];
		
		[NSBundle loadNibNamed:@"Preferences" owner:sharedPreferenceController];
	}
	
	return self;
}

- (void)dealloc
{
	[blankView release];
	[super dealloc];
}

- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillClose:)
						name:@"NSWindowWillCloseNotification" object:NSApp];

	/* Set the required information for all preference sections. */
	preferenceItems = [[NSDictionary dictionaryWithObjectsAndKeys:
			[NSArray arrayWithObjects:@"preference_general", generalController, local(@"General"), nil], @"General",
			[NSArray arrayWithObjects:@"preference_display", displayController, local(@"Display"), nil], @"Display",
			[NSArray arrayWithObjects:@"preference_environment", environmentController, local(@"Environment"), nil], @"Environment",
			[NSArray arrayWithObjects:@"preference_keys", keysController, local(@"SSH Keys"), nil], @"SSH Keys",
			[NSArray arrayWithObjects:@"preference_tunnels", tunnelsController, local(@"Tunnels"), nil], @"Tunnels",
			[NSArray arrayWithObjects:@"preference_security", securityController, local(@"Security"), nil], @"Security",
			[NSArray arrayWithObjects:@"preference_growl", growlController, local(@"Growl"), nil], @"Growl",
			nil]
		retain];

	/* Define the precedence of the sections. */
	preferenceItemsKeys = [[NSArray arrayWithObjects:@"General", @"Display", @"SSH Keys", @"Tunnels", @"Security", @"Environment", @"Growl", nil] retain];

	toolbar = [[NSToolbar alloc] initWithIdentifier:@"preferenceToolbar"];
	[toolbar setDelegate:self];
	[toolbar setAllowsUserCustomization:NO];
	[toolbar setAutosavesConfiguration:NO];
	[window setToolbar:[toolbar autorelease]];
	
	[self switchToView:@"General"];

	[[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
}

- (void)showWindow
{
	[window makeKeyAndOrderFront:self];
}

- (NSWindow *)window
{
	return window;
}

- (void)resizeWindowToSize:(NSSize)size
{
	NSRect frame, contentRect;
	float toolbarHeight, newHeight;
	
	/* Determine the toolbar height. */
	contentRect = [NSWindow contentRectForFrameRect:[window frame] styleMask:[window styleMask]];
	toolbarHeight = (NSHeight(contentRect) - NSHeight([[window contentView] frame]));
	
	newHeight = size.height;

	frame = [NSWindow contentRectForFrameRect:[window frame] styleMask:[window styleMask]];
	
	frame.origin.y += frame.size.height;
	frame.origin.y -= newHeight + toolbarHeight;
	frame.size.height = newHeight + toolbarHeight;
	frame.size.width = 475;
	
	frame = [NSWindow frameRectForContentRect:frame styleMask:[window styleMask]];
	
	[window setFrame:frame display:YES animate:YES];
}

/* Switch to a preference section from a toolbar. Calls switchToView. */
- (void)switchToViewFromToolbar:(NSToolbarItem *)item
{
	[self switchToView:[item itemIdentifier]];
}

/* Switch to a preference section. */
- (void)switchToView:(NSString *)identifier
{
	NSArray *array;

	if(((array = [preferenceItems objectForKey:identifier])) && ([array count] > 1)) 
	{
		if(([array objectAtIndex:1]) && (currentController != [array objectAtIndex:1]))
		{
			[currentController closePreferences];

			currentController = [array objectAtIndex:1];

			[window setContentView:blankView];
			[window setTitle:[NSString stringWithFormat:@"%@ - %@", local(@"Preferences"), [array objectAtIndex:2]]];
			[self resizeWindowToSize:[currentController viewSize]];

			if ([toolbar respondsToSelector:@selector(setSelectedItemIdentifier:)])
				[toolbar setSelectedItemIdentifier:identifier];
			[window setContentView:[currentController view]];

			[currentController loadPreferences];
		}
	}
}

- (void)windowWillClose:(NSNotification *)notification
{
	if([notification object] == window)
	{
		[currentController closePreferences];
	}
}

/* Toolbar Delegates. */

/* Initialize the items. */
- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	NSArray *array;

	if((array = [preferenceItems objectForKey:itemIdentifier])) 
	{
		NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];

		[item setLabel:[array objectAtIndex:2]];
		[item setPaletteLabel:[array objectAtIndex:2]];
		[item setImage:[NSImage imageNamed:[array objectAtIndex:0]]];
		[item setTarget:self];
		[item setAction:@selector(switchToViewFromToolbar:)];

		return [item autorelease];
	}
	
	return nil;
}

/* Return the allowed item identifiers. */
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
	return preferenceItemsKeys;
}

/* Return the default item identifiers. */
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
	return preferenceItemsKeys;
}

/* Return the selectable item identifiers (>10.3). */
- (NSArray*)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return preferenceItemsKeys;
}

@end
