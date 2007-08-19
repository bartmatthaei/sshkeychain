#import "GeneralView.h"

#include <unistd.h>
#include <sys/types.h>

#import "PreferenceController.h"

@implementation GeneralView
	
- (void)loadPreferences
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	if([[prefs stringForKey:SSHToolsPathString] isEqualToString:@""]) {
		[prefs setObject:@"/usr/bin/" forKey:SSHToolsPathString];
	}
	
	if([[prefs stringForKey:SocketPathString] isEqualToString:@""]) {
		[prefs setObject:[NSString stringWithFormat:@"/tmp/%d/SSHKeychain.socket", getuid()] forKey:SocketPathString];
	}

	[sshToolsPath setStringValue:[prefs stringForKey:SSHToolsPathString]];
	[socketPath setStringValue:[prefs stringForKey:SocketPathString]];
	
	[sshToolsPath setRefusesFirstResponder:YES];
	[socketPath setRefusesFirstResponder:YES];

	[checkForUpdatesOnStartup setState:[prefs boolForKey:CheckForUpdatesOnStartupString]];
}

- (void)savePreferences
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	[prefs setObject:[sshToolsPath stringValue] forKey:SSHToolsPathString];
	[prefs setObject:[socketPath stringValue] forKey:SocketPathString];
	[prefs setBool:[checkForUpdatesOnStartup state] forKey:CheckForUpdatesOnStartupString];

	[prefs synchronize];
}

@end
