#import "Controller.h"

#include <sys/types.h>
#include <unistd.h>
#include <utime.h>

#import "PreferenceController.h"
#import "UpdateController.h"

#import "Libs/SSHAgent.h"
#import "Libs/SSHKeychain.h"
#import "Libs/SSHTunnel.h"

#include <objc/objc-class.h>
#include <objc/objc-runtime.h>

#include "SSHKeychain_Prefix.pch"

Controller *sharedController;

NSString *local(NSString *theString)
{
	return NSLocalizedString(theString, nil);
}	

@implementation Controller

- (id)init
{
	NSMutableDictionary *defaults, *dict;
	NSConnection *conn;
	NSString *path;
	NSTask *theTask;
	
	if(!(self = [super init]))
	{
		return nil;
	}

	conn = [NSConnection defaultConnection];
	
	[conn runInNewThread];
	[conn removeRunLoop:[NSRunLoop currentRunLoop]];

	/* Register the default settings */
	defaults = [NSMutableDictionary dictionaryWithObjects:
		[NSArray arrayWithObjects:
			@"/usr/bin/",
			[NSString stringWithFormat:@"/tmp/%d/SSHKeychain.socket", getuid()],
			@"YES",
			@"NO",
			@"1",
			@"4",
			@"4",
			@"0",
			@"NO",
			@"3",
			[NSArray arrayWithObjects:@"~/.ssh/identity", @"~/.ssh/id_dsa", nil],
			@"NO",
			nil
		]
		forKeys:
		[NSArray arrayWithObjects:
			sshToolsPathString,
			socketPathString,
			addKeysOnConnectionString,
			askForConfirmationString,
			onSleepString,
			onScreensaverString,
			followKeychainString,
			minutesOfSleepString,
			checkForUpdatesOnStartupString,
			displayString,
			@"Keys",
			manageGlobalEnvironmentString,
			nil
		]
	];

												
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];

	path = [[[NSBundle mainBundle] bundlePath] stringByAppendingString:@"/Contents/Info.plist"];
	dict = [[[NSMutableDictionary alloc] initWithContentsOfFile:path] autorelease];
		
	if(dict == nil)
	{
		dict = [NSMutableDictionary dictionary];
	}
		
	if([[NSUserDefaults standardUserDefaults] integerForKey:displayString] == 1)
	{
		if((![[dict objectForKey:@"LSUIElement"] isEqualToString:@"1"]) &&
		   ([[NSFileManager defaultManager] isWritableFileAtPath:path]))
		{
			[dict setObject:@"1" forKey:@"LSUIElement"];
			if(![dict writeToFile:path atomically:YES])
			{
				NSLog(@"DEBUG: Couldn't write Info.plist.");
				exit(0);
			}
	
			/* Change the bundle's modification time to let LaunchServices know we've
			 * changed something. */
			if(utime([[[NSBundle mainBundle] bundlePath] cString], nil) == -1)
			{
				NSLog(@"DEBUG: utime on bundlePath failed.");
				exit(0);
			}			

			theTask = [[NSTask alloc] init];
			[theTask setLaunchPath:@"/usr/bin/open"];
			[theTask setArguments:[NSArray arrayWithObject:[[NSBundle mainBundle] bundlePath]]];
			[theTask launch];
			exit(0);
		}
	}
	
	else
	{
		if((![[dict objectForKey:@"LSUIElement"] isEqualToString:@"0"]) && ([dict objectForKey:@"LSUIElement"]))
		{
			[dict setObject:@"0" forKey:@"LSUIElement"];
			[dict writeToFile:path atomically:YES];
	
			/* Change the bundle's modification time to let LaunchServices know we've
				* changed something. */
			if(utime([[[NSBundle mainBundle] bundlePath] cString], nil) == -1)
			{
				NSLog(@"DEBUG: utime on bundlePath failed.");
			}
	
			theTask = [[NSTask alloc] init];
			[theTask setLaunchPath:@"/usr/bin/open"];
			[theTask setArguments:[NSArray arrayWithObject:[[NSBundle mainBundle] bundlePath]]];
			[theTask launch];
			exit(0);
		}
	}
	

	[conn setRootObject:self];
	if([conn registerName:@"SSHKeychain"] == NO)
	{
		NSLog(@"SSHKeychain already running");
		exit(0);
	}

	else {
		NSLog(@"Registered connection as SSHKeychain");
	}

	[NSApp setApplicationIconImage:[[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForImageResource:@"SSHKeychain"]]];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(appleKeychainNotification:) name:@"AppleKeychainLocked" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(appleKeychainNotification:) name:@"AppleKeychainUnlocked" object:nil];

	passphraseIsRequestedLock = [[NSLock alloc] init];
	appleKeychainUnlockedLock = [[NSLock alloc] init];

	sharedController = self;

	timestamp = 0;

	return self;
}

+ (Controller *)sharedController
{
	if(!sharedController) {
		return [[Controller alloc] init];
	}

	return sharedController;
}

- (void)dealloc
{
	[passphraseIsRequestedLock dealloc];
	[appleKeychainUnlockedLock dealloc];

	[super dealloc];
}

- (void)awakeFromNib
{
	NSStatusBar *statusbar;

	/* Create a statusbar item if needed. */
	int display = [[NSUserDefaults standardUserDefaults] integerForKey:displayString];
	
	if((display == 1) || (display == 3))
	{
		statusbar = [NSStatusBar systemStatusBar];
		[statusitemLock lock];
		statusitem = [statusbar statusItemWithLength:NSVariableStatusItemLength];

		[statusitem retain];
		[statusitem setHighlightMode:YES];
		[statusitem setImage:[NSImage imageNamed:@"small_icon_empty"]];
		[statusitem setMenu:statusbarMenu];
	
		[statusitemLock unlock];

		[NSApp unhide];
	}

	SecKeychainStatus status;
	SecKeychainGetStatus(nil, &status);

	if(status & 1)
	{
		[appleKeychainUnlockedLock lock];
		appleKeychainUnlocked = YES;
		[appleKeychainUnlockedLock unlock];

		[dockMenuAppleKeychainItem setTitle:local(@"LockAppleKeychain")];
		[statusbarMenuAppleKeychainItem setTitle:local(@"LockAppleKeychain")];
	}

	else
	{
		[appleKeychainUnlockedLock lock];
		appleKeychainUnlocked = NO;
		[appleKeychainUnlockedLock unlock];

		[dockMenuAppleKeychainItem setTitle:local(@"UnlockAppleKeychain")];
		[statusbarMenuAppleKeychainItem setTitle:local(@"UnlockAppleKeychain")];
	}
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	if([[NSUserDefaults standardUserDefaults] boolForKey:useGlobalEnvironmentString] == YES)
	{
		NSString *path = [[NSString stringWithString:@"~/.MacOSX/environment.plist"] stringByExpandingTildeInPath];
		NSString *socketPath = [[NSUserDefaults standardUserDefaults] stringForKey:socketPathString];
		NSString *macOSXDir = [[NSString stringWithString:@"~/.MacOSX"] stringByExpandingTildeInPath];
		NSMutableDictionary *dict; 

		BOOL isDirectory;

		/* If ~/.MacOSX/ doesn't exists, create a directory. */
		if(![[NSFileManager defaultManager] fileExistsAtPath:macOSXDir isDirectory:&isDirectory])
		{
        		[[NSFileManager defaultManager] createDirectoryAtPath:macOSXDir attributes:nil];
		}

		/* If ~/.MacOSX is a file, instead of a directory, remove it and create a directory. */
		else if(isDirectory == NO)
		{
			[[NSFileManager defaultManager] removeFileAtPath:macOSXDir handler:nil];
        		[[NSFileManager defaultManager] createDirectoryAtPath:macOSXDir attributes:nil];
		}

		/* If ~/.MacOSX/environment.plist doesn't exists, make a new dictionary. */
		if((dict = [[[NSMutableDictionary alloc] initWithContentsOfFile:path] autorelease]) == nil)
		{
			dict = [NSMutableDictionary dictionary];
		}

		if([dict objectForKey:@"SSH_AUTH_SOCK"] == nil)
		{
			[dict setObject:socketPath forKey:@"SSH_AUTH_SOCK"];
			[dict writeToFile:path atomically:YES];
			[self warningPanelWithTitle:@"SSH_AUTH_SOCK"
				  andMessage:local(@"AddedAuthsockToEnvironment")];
		}

		if(!([[dict objectForKey:@"SSH_AUTH_SOCK"] isEqualToString:socketPath]))
		{
			[dict setObject:socketPath forKey:@"SSH_AUTH_SOCK"];
			[dict writeToFile:path atomically:YES];
			[self warningPanelWithTitle:@"SSH_AUTH_SOCK"
				andMessage:local(@"ChangedAuthsockInEnvironment")];
		}
	}

	if([[NSUserDefaults standardUserDefaults] boolForKey:checkForUpdatesOnStartupString] == YES)
	{
		[[UpdateController sharedController] checkForUpdatesWithWarnings:NO];
	}
}

- (void)setStatus:(BOOL)status
{
	if(status) {
		[statusitemLock lock];
		[statusitem setImage:[NSImage imageNamed:@"small_icon"]];
		[statusitemLock unlock];
	} else {
		[statusitemLock lock];
		[statusitem setImage:[NSImage imageNamed:@"small_icon_empty"]];
		[statusitemLock unlock];
	}
}

- (void)setToolTip:(NSString *)tooltip
{
	[statusitemLock lock];
	[statusitem setToolTip:tooltip];
	[statusitemLock unlock];
}

- (IBAction)checkForUpdatesFromUI:(id)sender
{
	[[UpdateController sharedController] checkForUpdatesWithWarnings:YES];
}

- (IBAction)preferences:(id)sender
{
	/* The preferences class can handle things itself. Just tell it to open. */
	[PreferenceController openPreferencesWindow];
}

- (IBAction)toggleAppleKeychainLock:(id)sender
{
	ProcessSerialNumber focusSerialNumber;
	BOOL giveFocusBack = NO;

	[appleKeychainUnlockedLock lock];
	if(appleKeychainUnlocked == YES)
	{
		[appleKeychainUnlockedLock unlock];
		SecKeychainLock(nil);
	}

	else
	{
		[appleKeychainUnlockedLock unlock];

		if([[NSUserDefaults standardUserDefaults] integerForKey:displayString] != 1)
		{
			giveFocusBack = YES;
			GetFrontProcess(&focusSerialNumber);
		}

		[NSApp activateIgnoringOtherApps:YES];
		SecKeychainUnlock(nil, 0, nil, 0);

		if(giveFocusBack)
		{
			SetFrontProcess(&focusSerialNumber);
			giveFocusBack = NO;
		}
	}
}

- (NSString *)askPassphrase:(NSString *)question withInteraction:(BOOL)interaction
{
	char *serviceName;
	const char *accountName;
	char *kcPassword;
	UInt32 passwordLength;
	SecKeychainStatus status;

	SInt32 error;
	CFUserNotificationRef notification;
	CFOptionFlags response;
	CFStringRef enteredPassphrase;

	NSString *passphrase, *firstQuestion;
	NSMutableDictionary *dict;

	ProcessSerialNumber focusSerialNumber;
	BOOL giveFocusBack = NO;
		
	[passphraseIsRequestedLock lock];
	if(passphraseIsRequested == YES)
	{
		[passphraseIsRequestedLock unlock];
		return nil;
	}

	passphraseIsRequested = YES;

	[passphraseIsRequestedLock unlock];

	firstQuestion = @"Enter passphrase for ";

	if([question hasPrefix:firstQuestion])
	{
		accountName = [[[[question substringFromIndex:[firstQuestion length]]
componentsSeparatedByString:@": "] objectAtIndex:0] cString];
		serviceName = "SSHKeychain";

		SecKeychainGetStatus(nil, &status);

		[appleKeychainUnlockedLock lock];
		
		if(!appleKeychainUnlocked)
		{
			if([[NSUserDefaults standardUserDefaults] integerForKey:displayString] != 1)
			{
				giveFocusBack = YES;
				GetFrontProcess(&focusSerialNumber);
			}

			[NSApp activateIgnoringOtherApps:YES];
		}
		
		[appleKeychainUnlockedLock unlock];

		status = SecKeychainFindGenericPassword(nil, strlen(serviceName), serviceName, strlen(accountName), accountName, &passwordLength, (void **)&kcPassword, nil);

		if(giveFocusBack)
		{
			SetFrontProcess(&focusSerialNumber);
			giveFocusBack = NO;
		}
		
		[passphraseIsRequestedLock lock];
		passphraseIsRequested = NO;
		[passphraseIsRequestedLock unlock];
		
		if(status == 0)
		{
			kcPassword[passwordLength] = '\0';
			
			return [NSString stringWithCString:kcPassword];
		}
	}

	if(interaction)
	{
		/* Dictionary for the panel. */
		dict = [NSMutableDictionary dictionary];

		[dict setObject:local(@"Passphrase") forKey:(NSString *)kCFUserNotificationAlertHeaderKey];
		[dict setObject:question forKey:(NSString *)kCFUserNotificationAlertMessageKey];

		if([question hasPrefix:firstQuestion])
		{
			[dict setObject:local(@"AddPassphraseToAppleKeychain") forKey:(NSString *)kCFUserNotificationCheckBoxTitlesKey];
		}

		[dict setObject:[NSURL fileURLWithPath:[[[NSBundle mainBundle] resourcePath]
					stringByAppendingString:@"/SSHKeychain.icns"]] forKey:(NSString *)kCFUserNotificationIconURLKey];

		[dict setObject:@"" forKey:(NSString *)kCFUserNotificationTextFieldTitlesKey];
		[dict setObject:local(@"Ok") forKey:(NSString *)kCFUserNotificationDefaultButtonTitleKey];
		[dict setObject:local(@"Cancel") forKey:(NSString *)kCFUserNotificationAlternateButtonTitleKey];

		/* Display a passphrase request notification. */
		notification = CFUserNotificationCreate(nil, 30, CFUserNotificationSecureTextField(0), &error, (CFDictionaryRef)dict);

		/* If there was an error, return nil. */
		if(error)
		{
			[passphraseIsRequestedLock lock];
			passphraseIsRequested = NO;
			[passphraseIsRequestedLock unlock];
			return nil;
		}
		
		/* If we couldn't receive a response, return nil. */
		if(CFUserNotificationReceiveResponse(notification, 0, &response))
		{
			[passphraseIsRequestedLock lock];
			passphraseIsRequested = NO;
			[passphraseIsRequestedLock unlock];
			return nil;
		}

		/* If OK wasn't pressed, return nil. */
		if((response & 0x3) != kCFUserNotificationDefaultResponse)
		{
			[passphraseIsRequestedLock lock];
			passphraseIsRequested = NO;
			[passphraseIsRequestedLock unlock];
			return nil;
		}
		
		/* Get the passphrase from the textfield. */
		enteredPassphrase = CFUserNotificationGetResponseValue(notification, kCFUserNotificationTextFieldValuesKey, 0);

		if(enteredPassphrase != nil)
		{
			passphrase = [NSString stringWithString:(NSString *)enteredPassphrase];
			CFRelease(notification);
			
			if(([question hasPrefix:firstQuestion]) && (response & CFUserNotificationCheckBoxChecked(0)))
			{
				accountName = [[[[question substringFromIndex:[firstQuestion length]] componentsSeparatedByString:@": "] objectAtIndex:0] cString];
				serviceName = "SSHKeychain";
				
				[appleKeychainUnlockedLock lock];

				if(!appleKeychainUnlocked)
				{
					if([[NSUserDefaults standardUserDefaults] integerForKey:displayString] != 1)
					{
						giveFocusBack = YES;
						GetFrontProcess(&focusSerialNumber);
					}
					
					[NSApp activateIgnoringOtherApps:YES];
				}
				
				[appleKeychainUnlockedLock unlock];
				
				SecKeychainAddGenericPassword(nil, strlen(serviceName), serviceName, strlen(accountName), accountName, [passphrase length], (const void *)[passphrase cString], nil);
				
				if(giveFocusBack)
				{
					SetFrontProcess(&focusSerialNumber);
					giveFocusBack = NO;
				}
			}
			
			[passphraseIsRequestedLock lock];
			passphraseIsRequested = NO;
			[passphraseIsRequestedLock unlock];
			
			return passphrase;
		}

	}
	
	[passphraseIsRequestedLock lock];
	passphraseIsRequested = NO;
	[passphraseIsRequestedLock unlock];

	return nil;
}

- (IBAction)showAboutPanel:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	[NSApp orderFrontStandardAboutPanel:self];
}

- (void)warningPanelWithTitle:(NSString *)title andMessage:(NSString *)message
{
	[NSApp activateIgnoringOtherApps:YES];
	NSRunAlertPanel(title, message, nil, nil, nil);
}

- (NSData *)statusbarMenu
{
	return [NSArchiver archivedDataWithRootObject:statusbarMenu];
}

- (void)appleKeychainNotification:(NSNotification *)notification
{
	if([[notification name] isEqualToString:@"AppleKeychainLocked"])
	{
		[appleKeychainUnlockedLock lock];
		appleKeychainUnlocked = NO;
		[appleKeychainUnlockedLock unlock];

		[dockMenuAppleKeychainItem setTitle:local(@"UnlockAppleKeychain")];
		[statusbarMenuAppleKeychainItem setTitle:local(@"UnlockAppleKeychain")];
	}

	else if([[notification name] isEqualToString:@"AppleKeychainUnlocked"])
	{
		[appleKeychainUnlockedLock lock];
		appleKeychainUnlocked = YES;
		[appleKeychainUnlockedLock unlock];

		[dockMenuAppleKeychainItem setTitle:local(@"LockAppleKeychain")];
		[statusbarMenuAppleKeychainItem setTitle:local(@"LockAppleKeychain")];
	}
}

@end
