#import "DisplayView.h"

#include <utime.h>

#import "PreferenceController.h"

@implementation DisplayView
	
- (void)loadPreferences
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	[display selectItemAtIndex:[display indexOfItemWithTag:[prefs integerForKey:displayString]]];
}

- (void)savePreferences
{
	NSMutableDictionary *dict;
	NSString *path;
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	/* If the display has changed, warn the user, and write stuff to Info.plist in case it's needed. */
	if([[display selectedItem] tag] != [prefs integerForKey:displayString])
	{
		path = [[[NSBundle mainBundle] bundlePath] stringByAppendingString:@"/Contents/Info.plist"];
		dict = [[[NSMutableDictionary alloc] initWithContentsOfFile:path] autorelease];
		
		/* If we can't write Info.plist, don't allow the change. */
		if(![[NSFileManager defaultManager] isWritableFileAtPath:path]) {
			[self warningPanelWithTitle:local(@"DisplayPanelTitle") andMessage:local(@"DisplayChangeNotAllowed")];
			[display selectItemAtIndex:[display indexOfItemWithTag:[prefs integerForKey:displayString]]];
		
		} else {
		
			/* If LSUIElement is set to 1, the application doesn't display a dock item / main menu. */
			if([[display selectedItem] tag] == 1)
			{
				[dict setObject:@"1" forKey:@"LSUIElement"];
			}
			else
			{
				[dict removeObjectForKey:@"LSUIElement"];
			}
			
			[dict writeToFile:path atomically:YES];
			
			/* Change the bundle's modification time to let LaunchServices know we've
			 * changed something. */
			if(utime([[[NSBundle mainBundle] bundlePath] cString], nil) == -1)
			{
				NSLog(@"DEBUG: utime on bundlePath failed.");
			}
			
			[prefs setInteger:[[display selectedItem] tag] forKey:displayString];
			[prefs synchronize];
			
			[self warningPanelWithTitle:local(@"DisplayPanelTitle") andMessage:local(@"DisplayPanelText")];
		}
	}
}

@end
