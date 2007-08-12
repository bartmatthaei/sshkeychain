#import "GrowlNotificationController.h"
#import "PreferenceController.h"

/* This function resides in Controller.m. */
extern NSString *local(NSString *theString);

@implementation GrowlNotificationController

- (void)awakeFromNib
{
	[GrowlApplicationBridge setGrowlDelegate:self];
}

- (NSDictionary *) registrationDictionaryForGrowl
{
	NSArray *notifications;
	
	notifications = [NSArray arrayWithObjects: @"Tunnel Opened", @"Tunnel Closed", @"Tunnel Restart", @"Warning", nil];
	
	NSDictionary *dict;
	dict = [NSDictionary dictionaryWithObjectsAndKeys:
		notifications, GROWL_NOTIFICATIONS_ALL,
		notifications, GROWL_NOTIFICATIONS_DEFAULT, nil];
	
	return (dict);
}

- (BOOL) isOn
{
	return ([[NSUserDefaults standardUserDefaults] boolForKey:UseGrowlString] == YES);
}

- (void) tunnelOpened:(NSString *) tunnelName
{
	if ([self isOn]) {
		[GrowlApplicationBridge 
			notifyWithTitle:local(@"TunnelOpened")
				description:[NSString stringWithFormat: @"(%@) %@", tunnelName, local(@"TunnelHasBeenOpened")]
		   notificationName:@"Tunnel Opened"
				   iconData:nil
				   priority:0
				   isSticky:NO
			   clickContext:nil];
	}
}

- (void) tunnelClosed:(NSString *) tunnelName
{
	if ([self isOn]) {
		[GrowlApplicationBridge 
			notifyWithTitle:local(@"TunnelClosed")
				description:[NSString stringWithFormat: @"(%@) %@", tunnelName, local(@"TunnelHasBeenClosed")]
		   notificationName:@"Tunnel Closed"
				   iconData:nil
				   priority:0
				   isSticky:NO
			   clickContext:nil];
	}
}

- (void) tunnelRestart:(NSString *) tunnelName
{
	if ([self isOn]) {
		[GrowlApplicationBridge 
			notifyWithTitle:local(@"TunnelRestart")
				description:[NSString stringWithFormat: @"(%@) %@", tunnelName, local(@"TunnelIsBeeingRestarted")]
		   notificationName:@"Tunnel Restart"
				   iconData:nil
				   priority:0
				   isSticky:NO
			   clickContext:nil];
	}
}

- (void) warningWithTitle:(NSString *)title andMessage:(NSString *)message
{
	if ([self isOn]) {
		[GrowlApplicationBridge 
			notifyWithTitle:title
				description:message
		   notificationName:@"Warning"
				   iconData:nil
				   priority:1
				   isSticky:YES
			   clickContext:nil];
	}
}

@end
