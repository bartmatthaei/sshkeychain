#import "SecurityView.h"

#import "PreferenceController.h"

@implementation SecurityView

- (void)loadPreferences
{
	NSUserDefaults *prefs;

	prefs = [NSUserDefaults standardUserDefaults];

	[minutesOfSleepTextfield setRefusesFirstResponder:YES];
	[checkScreensaverIntervalTextfield setRefusesFirstResponder:YES];
	[keyTimeoutTextfield setRefusesFirstResponder:YES];

	[addKeysOnConnection setState:[[NSUserDefaults standardUserDefaults] boolForKey:AddKeysOnConnectionString]];
	[askForConfirmation setState:[[NSUserDefaults standardUserDefaults] boolForKey:AskForConfirmationString]];
        [addInteractivePasswordsToKeychain setState:[[NSUserDefaults standardUserDefaults] boolForKey:AddInteractivePasswordString]];

	[onSleep selectItemAtIndex:[onSleep indexOfItemWithTag:[prefs integerForKey:OnSleepString]]];
	[onScreensaver selectItemAtIndex:[onScreensaver indexOfItemWithTag:[prefs integerForKey:OnScreensaverString]]];
	[followKeychain selectItemAtIndex:[followKeychain indexOfItemWithTag:[prefs integerForKey:FollowKeychainString]]];

	if([prefs integerForKey:OnSleepString] == 1)
	{
		[minutesOfSleep setEnabled:YES];
		[minutesOfSleepTextfield setEnabled:YES];
	}
	
	else
	{
		[minutesOfSleep setEnabled:NO];
		[minutesOfSleepTextfield setEnabled:NO];
	}
	
	[minutesOfSleepTextfield setIntValue:[prefs integerForKey:MinutesOfSleepString]];
	[minutesOfSleep setIntValue:[prefs integerForKey:MinutesOfSleepString]];
	
	if([prefs integerForKey:OnScreensaverString] > 1)
	{
		[checkScreensaverInterval setEnabled:YES];
		[checkScreensaverIntervalTextfield setEnabled:YES];
	}
	
	else
	{
		[checkScreensaverInterval setEnabled:NO];
		[checkScreensaverIntervalTextfield setEnabled:NO];
	}

	[checkScreensaverIntervalTextfield setIntValue:[prefs integerForKey:CheckScreensaverIntervalString]];
	[checkScreensaverInterval setIntValue:[prefs integerForKey:CheckScreensaverIntervalString]];
	
	[keyTimeoutTextfield setIntValue:[prefs integerForKey:KeyTimeoutString]];
	[keyTimeout setIntValue:[prefs integerForKey:KeyTimeoutString]];

	[useCustomSecuritySettings setState:[[NSUserDefaults standardUserDefaults] boolForKey:UseCustomSecuritySettingsString]];

	if([[NSUserDefaults standardUserDefaults] boolForKey:UseCustomSecuritySettingsString]) 
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

	[prefs setBool:[useCustomSecuritySettings state] forKey:UseCustomSecuritySettingsString];
	
	if([useCustomSecuritySettings state])
	{
		[prefs setBool:[addKeysOnConnection state] forKey:AddKeysOnConnectionString];
		[prefs setBool:[askForConfirmation state] forKey:AskForConfirmationString];
                [prefs setBool:[addInteractivePasswordsToKeychain state] forKey:AddInteractivePasswordString];

		[prefs setInteger:[[onSleep selectedItem] tag] forKey:OnSleepString];
		[prefs setInteger:[[onScreensaver selectedItem] tag] forKey:OnScreensaverString];
		[prefs setInteger:[[followKeychain selectedItem] tag] forKey:FollowKeychainString];
		[prefs setInteger:[minutesOfSleepTextfield intValue] forKey:MinutesOfSleepString];
		
		[prefs setInteger:[checkScreensaverIntervalTextfield intValue] forKey:CheckScreensaverIntervalString];
		[prefs setInteger:[keyTimeoutTextfield intValue] forKey:KeyTimeoutString];

	} 

	else
	{
		[prefs setBool:YES forKey:AddKeysOnConnectionString];
		[prefs setBool:NO forKey:AskForConfirmationString];
                [prefs setBool:NO forKey:AddInteractivePasswordString];

		[prefs setInteger:1 forKey:OnSleepString];
		[prefs setInteger:4 forKey:OnScreensaverString];
		[prefs setInteger:4 forKey:FollowKeychainString];
		[prefs setInteger:0 forKey:MinutesOfSleepString];
		[prefs setInteger:30 forKey:CheckScreensaverIntervalString];
		[prefs setInteger:0 forKey:KeyTimeoutString];
	}

	[prefs synchronize];
}

- (NSSize)viewSize
{
	NSSize size = [view frame].size;

	if([[NSUserDefaults standardUserDefaults] boolForKey:UseCustomSecuritySettingsString])
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
	[prefs setBool:[sender state] forKey:UseCustomSecuritySettingsString];
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

		[prefs setBool:YES forKey:AddKeysOnConnectionString];
		[prefs setBool:NO forKey:AskForConfirmationString];
                [prefs setBool:NO forKey:AddInteractivePasswordString];

		[prefs setInteger:1 forKey:OnSleepString];
		[prefs setInteger:4 forKey:OnScreensaverString];
		[prefs setInteger:4 forKey:FollowKeychainString];
		[prefs setInteger:0 forKey:MinutesOfSleepString];		
		[prefs setInteger:30 forKey:CheckScreensaverIntervalString];
		[prefs setInteger:0 forKey:KeyTimeoutString];

		[prefs synchronize];

		[addKeysOnConnection setState:[prefs boolForKey:AddKeysOnConnectionString]];
		[askForConfirmation setState:[prefs boolForKey:AskForConfirmationString]];
                [addInteractivePasswordsToKeychain setState:[prefs boolForKey:AddInteractivePasswordString]];

		[onSleep selectItemAtIndex:[onSleep indexOfItemWithTag:[prefs integerForKey:OnSleepString]]];
		[onScreensaver selectItemAtIndex:[onScreensaver indexOfItemWithTag:[prefs integerForKey:OnScreensaverString]]];
		[followKeychain selectItemAtIndex:[followKeychain indexOfItemWithTag:[prefs integerForKey:FollowKeychainString]]];

		if([prefs integerForKey:OnSleepString] == 1)
		{
			[minutesOfSleep setEnabled:YES];
			[minutesOfSleepTextfield setEnabled:YES];
		}
	
		else
		{
			[minutesOfSleep setEnabled:NO];
			[minutesOfSleepTextfield setEnabled:NO];
		}
	
		[minutesOfSleepTextfield setIntValue:[prefs integerForKey:MinutesOfSleepString]];
		[minutesOfSleep setIntValue:[prefs integerForKey:MinutesOfSleepString]];
		
		if([prefs integerForKey:OnScreensaverString] > 1)
		{
			[checkScreensaverInterval setEnabled:YES];
			[checkScreensaverIntervalTextfield setEnabled:YES];
		}
	
		else
		{
			[checkScreensaverInterval setEnabled:NO];
			[checkScreensaverIntervalTextfield setEnabled:NO];
		}
		
		[checkScreensaverIntervalTextfield setIntValue:[prefs integerForKey:CheckScreensaverIntervalString]];
		[checkScreensaverInterval setIntValue:[prefs integerForKey:CheckScreensaverIntervalString]];
		
		[keyTimeoutTextfield setIntValue:[prefs integerForKey:KeyTimeoutString]];
		[keyTimeout setIntValue:[prefs integerForKey:KeyTimeoutString]];

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

/* The key timeout slidebar has changed. */
- (IBAction)changeKeyTimeout:(id)sender
{
	if(sender == keyTimeout)
	{
		[keyTimeoutTextfield setIntValue:[sender intValue]];
	}
	
	else if(sender == keyTimeoutTextfield)
	{
		[keyTimeoutTextfield setIntValue:[sender intValue]];
		[keyTimeout setIntValue:[sender intValue]];
	}
}


@end
