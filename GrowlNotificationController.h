/* GrowlNotificationController */

#import <Cocoa/Cocoa.h>
#import <Growl/Growl.h>

#import "Libs/SSHTunnel.h"

@interface GrowlNotificationController : NSObject <GrowlApplicationBridgeDelegate>
{
}
- (NSDictionary *) registrationDictionaryForGrowl; 

/* events */
- (void) tunnelOpened;
- (void) warningWithTitle:(NSString *)title andMessage:(NSString *)message;
@end
