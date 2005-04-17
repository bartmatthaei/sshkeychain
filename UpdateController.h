#import <Cocoa/Cocoa.h>
#import <Security/Security.h>

@interface UpdateController : NSObject
{
}

+ (UpdateController *)sharedController;

- (void)checkForUpdatesWithWarnings:(BOOL)warnings;

- (void)warningPanelWithTitle:(NSString *)title andMessage:(NSString *)message;

@end
