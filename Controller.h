#import <Cocoa/Cocoa.h>
#import <Security/Security.h>

#define remoteVersionURL @"http://www.sshkeychain.org/latestversion.xml"

@protocol UI

- (NSString *)askPassphrase:(NSString *)question withInteraction:(BOOL)interaction;
- (void)warningPanelWithTitle:(NSString *)title andMessage:(NSString *)message;
- (NSData *)statusbarMenu;

@end

@interface Controller : NSObject
{
	IBOutlet id statusbarMenu;

	IBOutlet id dockMenuAppleKeychainItem;
	IBOutlet id statusbarMenuAppleKeychainItem;

	id passphraseRequester;
	
	BOOL passphraseIsRequested;
	BOOL appleKeychainUnlocked;
	
	NSStatusItem *statusitem;

	int timestamp;

	/* Locks */
	NSLock *passphraseIsRequestedLock;
	NSLock *appleKeychainUnlockedLock;
	NSLock *statusitemLock;

}

+ (Controller *)sharedController;

- (void)setStatus:(BOOL)status;
- (void)setToolTip:(NSString *)tooltip;

- (IBAction)checkForUpdatesFromUI:(id)sender;
- (IBAction)preferences:(id)sender;

- (IBAction)toggleAppleKeychainLock:(id)sender;

- (NSString *)askPassphrase:(NSString *)question withInteraction:(BOOL)interaction;

- (IBAction)showAboutPanel:(id)sender;

- (void)warningPanelWithTitle:(NSString *)title andMessage:(NSString *)message;

- (NSData *)statusbarMenu;

@end
