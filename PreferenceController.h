/* $Id$ */

#import <Cocoa/Cocoa.h>

#import "PreferenceView.h"

#define sshToolsPathString @"SSH Tools Path"
#define socketPathString @"Authentication Socket Path"
#define displayString @"Display"
#define addKeysOnConnectionString @"Add Keys On Connection"
#define askForConfirmationString @"Ask for Confirmation"
#define onSleepString @"On Sleep"
#define onScreensaverString @"On Screensaver"
#define followKeychainString @"Follow Keychain"
#define minutesOfSleepString @"Minutes of Sleep"
#define manageGlobalEnvironmentString @"Manage Global Environment"
#define checkForUpdatesOnStartupString @"Check For Updates On Startup"
#define tunnelsString @"Tunnels"
#define useGlobalEnvironmentString @"Use Global Environment ~/.MacOSX/environment.plist"
#define useCustomSecuritySettingsString @"Use Custom Security Settings"

@interface PreferenceController : NSObject 
{
	NSDictionary *preferenceItems;
	NSArray *preferenceItemsKeys;
	
	IBOutlet NSWindow *window;
	
	IBOutlet PreferenceView *generalController, *displayController, *keysController, *tunnelsController, *securityController, *environmentController;

	NSView *blankView;

	PreferenceView *currentController;
	
	NSToolbar *toolbar;
}

+ (id)preferenceController;
+ (void)openPreferencesWindow;
- (void)showWindow;
- (NSWindow *)window;

- (void)switchToViewFromToolbar:(NSToolbarItem *)item;
- (void)switchToView:(NSString *)identifier;

- (void)resizeWindowToSize:(NSSize)size;

/* NSToolbar delegates. */
- (NSToolbarItem*)toolbar:(NSToolbar*)toolbar itemForItemIdentifier:(NSString*)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag;
- (NSArray*)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar;
- (NSArray*)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar;
- (NSArray*)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar;

@end
