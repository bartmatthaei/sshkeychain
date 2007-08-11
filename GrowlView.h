/* GrowlView */

#import <Cocoa/Cocoa.h>
#import "PreferenceView.h"

@interface GrowlView : PreferenceView
{
    IBOutlet id useGrowl, disableDialogNotificationsWhenUsingGrowl;
}
@end
