#import "GrowlNotificationController.h"
#import "PreferenceController.h"

@implementation GrowlNotificationController

- (void)awakeFromNib
{
	[GrowlApplicationBridge setGrowlDelegate:self];
}

- (NSDictionary *) registrationDictionaryForGrowl
{
	NSArray *notifications;
	
	notifications = [NSArray arrayWithObjects: @"Tunnel Opened", @"Warning", nil];
	
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

- (void) tunnelOpened
{
	if ([self isOn]) {
		[GrowlApplicationBridge 
			notifyWithTitle:@"Tunnel Opened"
				description:@"Yuppi!"
		   notificationName:@"Tunnel Opened"
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
