#import "GeneralView.h"

#include <unistd.h>
#include <sys/types.h>

#import "PreferenceController.h"

@implementation GeneralView
	
- (void)loadPreferences
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	if([[prefs stringForKey:sshToolsPathString] isEqualToString:@""]) {
		[prefs setObject:@"/usr/bin/" forKey:sshToolsPathString];
	}
	
	if([[prefs stringForKey:socketPathString] isEqualToString:@""]) {
		[prefs setObject:[NSString stringWithFormat:@"/tmp/%d/SSHKeychain.socket", getuid()] forKey:socketPathString];
	}

	[sshToolsPath setStringValue:[prefs stringForKey:sshToolsPathString]];
	[socketPath setStringValue:[prefs stringForKey:socketPathString]];
	
	[sshToolsPath setRefusesFirstResponder:YES];
	[socketPath setRefusesFirstResponder:YES];

	[checkForUpdatesOnStartup setState:[prefs boolForKey:checkForUpdatesOnStartupString]];
}

- (void)savePreferences
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	[prefs setObject:[sshToolsPath stringValue] forKey:sshToolsPathString];
	[prefs setObject:[socketPath stringValue] forKey:socketPathString];
	[prefs setBool:[checkForUpdatesOnStartup state] forKey:checkForUpdatesOnStartupString];

	[prefs synchronize];
}

@end
