#import "SecurityView.h"

#import "PreferenceController.h"

@implementation SecurityView

- (void)loadPreferences
{
	NSUserDefaults *prefs;

	prefs = [NSUserDefaults standardUserDefaults];

	[minutesOfSleepTextfield setRefusesFirstResponder:YES];

	[addKeysOnConnection setState:[[NSUserDefaults standardUserDefaults] boolForKey:addKeysOnConnectionString]];
	[askForConfirmation setState:[[NSUserDefaults standardUserDefaults] boolForKey:askForConfirmationString]];

	[onSleep selectItemAtIndex:[onSleep indexOfItemWithTag:[prefs integerForKey:onSleepString]]];
	[onScreensaver selectItemAtIndex:[onScreensaver indexOfItemWithTag:[prefs integerForKey:onScreensaverString]]];
	[followKeychain selectItemAtIndex:[followKeychain indexOfItemWithTag:[prefs integerForKey:followKeychainString]]];

	if([prefs integerForKey:onSleepString] == 1)
	{
		[minutesOfSleep setEnabled:YES];
	}
	
	else
	{
		[minutesOfSleep setEnabled:NO];
	}
	
	[minutesOfSleepTextfield setIntValue:[prefs integerForKey:minutesOfSleepString]];
	[minutesOfSleep setIntValue:[prefs integerForKey:minutesOfSleepString]];

	[useCustomSecuritySettings setState:[[NSUserDefaults standardUserDefaults] boolForKey:useCustomSecuritySettingsString]];

	if([[NSUserDefaults standardUserDefaults] boolForKey:useCustomSecuritySettingsString]) 
	{
		[view addSubview:customSecuritySettingsView];
	}
}

- (void)savePreferences
{
	NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

	[prefs setBool:[useCustomSecuritySettings state] forKey:useCustomSecuritySettingsString];
	
	if([useCustomSecuritySettings state])
	{
		[prefs setBool:[addKeysOnConnection state] forKey:addKeysOnConnectionString];
		[prefs setBool:[askForConfirmation state] forKey:askForConfirmationString];

		[prefs setInteger:[[onSleep selectedItem] tag] forKey:onSleepString];
		[prefs setInteger:[[onScreensaver selectedItem] tag] forKey:onScreensaverString];
		[prefs setInteger:[[followKeychain selectedItem] tag] forKey:followKeychainString];
		[prefs setInteger:[minutesOfSleepTextfield intValue] forKey:minutesOfSleepString];
	} 

	else
	{
		[prefs setBool:YES forKey:addKeysOnConnectionString];
		[prefs setBool:NO forKey:askForConfirmationString];

		[prefs setInteger:1 forKey:onSleepString];
		[prefs setInteger:4 forKey:onScreensaverString];
		[prefs setInteger:4 forKey:followKeychainString];
		[prefs setInteger:0 forKey:minutesOfSleepString];
	}

	[prefs synchronize];
}

- (NSSize)viewSize
{
	NSSize size = [view frame].size;

	if([[NSUserDefaults standardUserDefaults] boolForKey:useCustomSecuritySettingsString])
	{
		size.height = (70 + [customSecuritySettingsView frame].size.height);
	}

	else
	{
		size.height = 70;
	}

	return size;
}

- (IBAction)toggleCustomSecuritySettings:(id)sender
{
	NSUserDefaults *prefs;

	prefs = [NSUserDefaults standardUserDefaults];
	[prefs setBool:[sender state] forKey:useCustomSecuritySettingsString];
	[prefs synchronize];

	if([sender state] == YES)
	{
		[[PreferenceController preferenceController] resizeWindowToSize:[self viewSize]];
		[view addSubview:customSecuritySettingsView];
	}

	else if([sender state] == NO)
	{
		[customSecuritySettingsView removeFromSuperview];
		[[PreferenceController preferenceController] resizeWindowToSize:[self viewSize]];

		[prefs setBool:YES forKey:addKeysOnConnectionString];
		[prefs setBool:NO forKey:askForConfirmationString];

		[prefs setInteger:1 forKey:onSleepString];
		[prefs setInteger:4 forKey:onScreensaverString];
		[prefs setInteger:4 forKey:followKeychainString];
		[prefs setInteger:0 forKey:minutesOfSleepString];

		[prefs synchronize];

		[addKeysOnConnection setState:[prefs boolForKey:addKeysOnConnectionString]];
		[askForConfirmation setState:[prefs boolForKey:askForConfirmationString]];

		[onSleep selectItemAtIndex:[onSleep indexOfItemWithTag:[prefs integerForKey:onSleepString]]];
		[onScreensaver selectItemAtIndex:[onScreensaver indexOfItemWithTag:[prefs integerForKey:onScreensaverString]]];
		[followKeychain selectItemAtIndex:[followKeychain indexOfItemWithTag:[prefs integerForKey:followKeychainString]]];

		if([prefs integerForKey:onSleepString] == 1)
		{
			[minutesOfSleep setEnabled:YES];
		}
	
		else
		{
			[minutesOfSleep setEnabled:NO];
		}
	
		[minutesOfSleepTextfield setIntValue:[prefs integerForKey:minutesOfSleepString]];
		[minutesOfSleep setIntValue:[prefs integerForKey:minutesOfSleepString]];
	}
}

/* When the removeKeysAfterSleep option is toggled, the minutesOfSleep box needs to be greyed out or displayed. */
- (IBAction)changeOnSleep:(id)sender
{
	[minutesOfSleep setEnabled:[[sender selectedItem] tag]];
	[minutesOfSleepTextfield setEnabled:[[sender selectedItem] tag]];
}

/* The minutes of sleep slidebar has changed. */
- (IBAction)changeMinutesOfSleep:(id)sender
{
	if(sender == minutesOfSleep)
	{
		[minutesOfSleepTextfield setIntValue:[sender intValue]];
	}
	
	else if(sender == minutesOfSleepTextfield)
	{
		[minutesOfSleepTextfield setIntValue:[sender intValue]];
		[minutesOfSleep setIntValue:[sender intValue]];
	}
}

@end
