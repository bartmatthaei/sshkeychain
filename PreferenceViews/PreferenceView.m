/* $Id$ */

#import "PreferenceView.h"

#import "PreferenceController.h"

@implementation PreferenceView

/* Since PreferenceView is an abstract class, these functions are more or less empty. */

- (void)loadPreferences
{
}

- (void)closePreferences
{
	[self savePreferences];
}

- (void)savePreferences
{
}

/* Return the view. */
- (NSView *)view
{
	return view;
}

/* Return the view size. */
- (NSSize)viewSize
{
	return [view frame].size;
}

- (void)warningPanelWithTitle:(NSString *)title andMessage:(NSString *)message
{       
	NSRunAlertPanel(title, message, nil, nil, nil);
}

@end
