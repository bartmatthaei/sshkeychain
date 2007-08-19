#import <Cocoa/Cocoa.h>

/* This function resides in Controller.m. */
extern NSString *local(NSString *theString);

@interface PreferenceView : NSObject 
{
	NSView *view;
}

- (void)loadPreferences;
- (void)closePreferences;
- (void)savePreferences;

- (NSView *)view;
- (NSSize)viewSize;

- (void)warningPanelWithTitle:(NSString *)title andMessage:(NSString *)message;

@end
