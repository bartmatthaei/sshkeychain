#import <Cocoa/Cocoa.h>
#import <Security/Security.h>

#define remoteVersionURL @"http://www.sshkeychain.org/latestversion.xml"

@interface UpdateController : NSObject
{
}

+ (UpdateController *)sharedController;

- (void)checkForUpdatesWithWarnings:(BOOL)warnings;

- (void)warningPanelWithTitle:(NSString *)title andMessage:(NSString *)message;

@end
