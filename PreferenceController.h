#import <Cocoa/Cocoa.h>

#import "PreferenceView.h"

extern NSString *SSHToolsPathString;
extern NSString *SocketPathString;
extern NSString *DisplayString;
extern NSString *AddKeysOnConnectionString;
extern NSString *AskForConfirmationString;
extern NSString *OnSleepString;
extern NSString *OnScreensaverString;
extern NSString *FollowKeychainString;
extern NSString *MinutesOfSleepString;
extern NSString *ManageGlobalEnvironmentString;
extern NSString *CheckForUpdatesOnStartupString;
extern NSString *TunnelsString;
extern NSString *UseGlobalEnvironmentString;
extern NSString *UseCustomSecuritySettingsString;
extern NSString *CheckScreensaverIntervalString;
extern NSString *KeyTimeoutString;
extern NSString *AddInteractivePasswordString;

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

+ (PreferenceController *)sharedController;
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
