/* GrowlNotificationController */

#import <Cocoa/Cocoa.h>
#import <Growl/Growl.h>

#import "Libs/SSHTunnel.h"

@interface GrowlNotificationController : NSObject <GrowlApplicationBridgeDelegate>
{
}
- (NSDictionary *) registrationDictionaryForGrowl; 

/* events */
- (void) tunnelOpened:(NSString *) tunnelName;
- (void) tunnelClosed:(NSString *) tunnelName;
- (void) tunnelRestart:(NSString *) tunnelName;
- (void) warningWithTitle:(NSString *)title andMessage:(NSString *)message;
@end
