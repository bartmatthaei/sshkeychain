#import "PreferenceView.h"

@interface SecurityView : PreferenceView
{
	/* Security view. */
	IBOutlet id useCustomSecuritySettings, customSecuritySettingsView;

	/* Custom Security Settings View. */
	IBOutlet id addKeysOnConnection, askForConfirmation, followKeychain, onScreensaver, onSleep;
	IBOutlet id minutesOfSleep, minutesOfSleepTextfield, checkScreensaverInterval, checkScreensaverIntervalTextfield;
}

- (IBAction)changeOnSleep:(id)sender;
- (IBAction)changeMinutesOfSleep:(id)sender;

- (IBAction)changeOnScreensaver:(id)sender;
- (IBAction)changeCheckScreensaverInterval:(id)sender;

- (IBAction)toggleCustomSecuritySettings:(id)sender;

@end
