#import "GrowlView.h"
#import "PreferenceController.h"

@implementation GrowlView

- (void)loadPreferences
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	[useGrowl setState:[prefs boolForKey:UseGrowlString]];
	[disableDialogNotificationsWhenUsingGrowl setState:[prefs boolForKey:DisableDialogNotificationsWhenUsingGrowlString]];
}

- (void)savePreferences
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
	[prefs setBool:[useGrowl state] forKey:UseGrowlString];	
	[prefs setBool:[disableDialogNotificationsWhenUsingGrowl state] forKey:DisableDialogNotificationsWhenUsingGrowlString];
	[prefs synchronize];
}

@end
