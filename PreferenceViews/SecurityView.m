#import "SecurityView.h"

#import "PreferenceController.h"

@implementation SecurityView

- (void)loadPreferences
{
	NSUserDefaults *prefs;

	prefs = [NSUserDefaults standardUserDefaults];

	[minutesOfSleepTextfield setRefusesFirstResponder:YES];
	[checkScreensaverIntervalTextfield setRefusesFirstResponder:YES];

	[addKeysOnConnection setState:[[NSUserDefaults standardUserDefaults] boolForKey:addKeysOnConnectionString]];
	[askForConfirmation setState:[[NSUserDefaults standardUserDefaults] boolForKey:askForConfirmationString]];

	[onSleep selectItemAtIndex:[onSleep indexOfItemWithTag:[prefs integerForKey:onSleepString]]];
	[onScreensaver selectItemAtIndex:[onScreensaver indexOfItemWithTag:[prefs integerForKey:onScreensaverString]]];
	[followKeychain selectItemAtIndex:[followKeychain indexOfItemWithTag:[prefs integerForKey:followKeychainString]]];

	if([prefs integerForKey:onSleepString] == 1)
	{
		[minutesOfSleep setEnabled:YES];
		[minutesOfSleepTextfield setEnabled:YES];
	}
	
	else
	{
		[minutesOfSleep setEnabled:NO];
		[minutesOfSleepTextfield setEnabled:NO];
	}
	
	[minutesOfSleepTextfield setIntValue:[prefs integerForKey:minutesOfSleepString]];
	[minutesOfSleep setIntValue:[prefs integerForKey:minutesOfSleepString]];
	
	if([prefs integerForKey:onScreensaverString] > 1)
	{
		[checkScreensaverInterval setEnabled:YES];
		[checkScreensaverIntervalTextfield setEnabled:YES];
	}
	
	else
	{
		[checkScreensaverInterval setEnabled:NO];
		[checkScreensaverIntervalTextfield setEnabled:NO];
	}

	[checkScreensaverIntervalTextfield setIntValue:[prefs integerForKey:checkScreensaverIntervalString]];
	[checkScreensaverInterval setIntValue:[prefs integerForKey:checkScreensaverIntervalString]];

	[useCustomSecuritySettings setState:[[NSUserDefaults standardUserDefaults] boolForKey:useCustomSecuritySettingsString]];

	if([[NSUserDefaults standardUserDefaults] boolForKey:useCustomSecuritySettingsString]) 
	{
		NSSize securitySize = [customSecuritySettingsView frame].size;
		securitySize.width = [self viewSize].width;
		[customSecuritySettingsView setFrameSize:securitySize];
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
		
		[prefs setInteger:[checkScreensaverIntervalTextfield intValue] forKey:checkScreensaverIntervalString];
	} 

	else
	{
		[prefs setBool:YES forKey:addKeysOnConnectionString];
		[prefs setBool:NO forKey:askForConfirmationString];

		[prefs setInteger:1 forKey:onSleepString];
		[prefs setInteger:4 forKey:onScreensaverString];
		[prefs setInteger:4 forKey:followKeychainString];
		[prefs setInteger:0 forKey:minutesOfSleepString];
		[prefs setInteger:30 forKey:checkScreensaverIntervalString];
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
		[[PreferenceController sharedController] resizeWindowToSize:[self viewSize]];
		NSSize settingsSize = [customSecuritySettingsView frame].size;
		settingsSize.width = [self viewSize].width;
		[customSecuritySettingsView setFrameSize:settingsSize];
		[view addSubview:customSecuritySettingsView];
	}

	else if([sender state] == NO)
	{
		[customSecuritySettingsView removeFromSuperview];
		[[PreferenceController sharedController] resizeWindowToSize:[self viewSize]];

		[prefs setBool:YES forKey:addKeysOnConnectionString];
		[prefs setBool:NO forKey:askForConfirmationString];

		[prefs setInteger:1 forKey:onSleepString];
		[prefs setInteger:4 forKey:onScreensaverString];
		[prefs setInteger:4 forKey:followKeychainString];
		[prefs setInteger:0 forKey:minutesOfSleepString];		
		[prefs setInteger:30 forKey:checkScreensaverIntervalString];

		[prefs synchronize];

		[addKeysOnConnection setState:[prefs boolForKey:addKeysOnConnectionString]];
		[askForConfirmation setState:[prefs boolForKey:askForConfirmationString]];

		[onSleep selectItemAtIndex:[onSleep indexOfItemWithTag:[prefs integerForKey:onSleepString]]];
		[onScreensaver selectItemAtIndex:[onScreensaver indexOfItemWithTag:[prefs integerForKey:onScreensaverString]]];
		[followKeychain selectItemAtIndex:[followKeychain indexOfItemWithTag:[prefs integerForKey:followKeychainString]]];

		if([prefs integerForKey:onSleepString] == 1)
		{
			[minutesOfSleep setEnabled:YES];
			[minutesOfSleepTextfield setEnabled:YES];
		}
	
		else
		{
			[minutesOfSleep setEnabled:NO];
			[minutesOfSleepTextfield setEnabled:NO];
		}
	
		[minutesOfSleepTextfield setIntValue:[prefs integerForKey:minutesOfSleepString]];
		[minutesOfSleep setIntValue:[prefs integerForKey:minutesOfSleepString]];
		
		if([prefs integerForKey:onScreensaverString] > 1)
		{
			[checkScreensaverInterval setEnabled:YES];
			[checkScreensaverIntervalTextfield setEnabled:YES];
		}
	
		else
		{
			[checkScreensaverInterval setEnabled:NO];
			[checkScreensaverIntervalTextfield setEnabled:NO];
		}
		
		[checkScreensaverIntervalTextfield setIntValue:[prefs integerForKey:checkScreensaverIntervalString]];
		[checkScreensaverInterval setIntValue:[prefs integerForKey:checkScreensaverIntervalString]];

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

/* When the On Screensaver option is toggled, the checkScreensaverInterval box needs to be greyed out or displayed. */
- (IBAction)changeOnScreensaver:(id)sender
{
	if([[sender selectedItem] tag] > 1) 
	{
		[checkScreensaverInterval setEnabled:YES];
		[checkScreensaverIntervalTextfield setEnabled:YES];
	}
	
	else
	{
		[checkScreensaverInterval setEnabled:NO];
		[checkScreensaverIntervalTextfield setEnabled:NO];
	}
}

/* The seconds of screensaver check interval slidebar has changed. */
- (IBAction)changeCheckScreensaverInterval:(id)sender
{
	int seconds = [sender intValue];
	
	if(seconds < 5)
	{
		seconds = 5;
	}
	
	if(seconds > 100) 
	{
		seconds = 100;
	}
	
	if(sender == checkScreensaverInterval)
	{
		[checkScreensaverIntervalTextfield setIntValue:seconds];
	}
	
	else if(sender == checkScreensaverIntervalTextfield)
	{
		[checkScreensaverIntervalTextfield setIntValue:seconds];
		[checkScreensaverInterval setIntValue:seconds];
	}
}

@end
