#import <Cocoa/Cocoa.h>
#import <IOKit/IOMessage.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <Security/Security.h>

#import "Libs/SSHAgent.h"
#import "TunnelController.h"

io_connect_t root_port;

int sleep_timestamp;

void powerchange_callback(void *x, io_service_t y, natural_t type, void *argument)
{
	switch(type)
	{
		case kIOMessageSystemWillSleep:
			sleep_timestamp = time(nil);
			IOAllowPowerChange(root_port,(long)argument);
			break;
		case kIOMessageCanSystemSleep:
			sleep_timestamp = time(nil);
			IOAllowPowerChange(root_port,(long)argument);
			break;
		case kIOMessageSystemHasPoweredOn:
			[[NSNotificationCenter defaultCenter]  postNotificationName:@"SKWake" object:nil];
			break;
	}
}

OSStatus keychain_locked(SecKeychainEvent keychainEvent, SecKeychainCallbackInfo *info, void *context)
{
	[[NSNotificationCenter defaultCenter]  postNotificationName:@"AppleKeychainLocked" object:nil];
	return 0;
}

OSStatus keychain_unlocked(SecKeychainEvent keychainEvent, SecKeychainCallbackInfo *info, void *context)
{
	[[NSNotificationCenter defaultCenter]  postNotificationName:@"AppleKeychainUnlocked" object:nil];
	return 0;
}

void sighandler(int num)
{
	SSHAgent *agent = [SSHAgent currentAgent];
	[agent stop];
	[[TunnelController sharedController] closeAllTunnels];
	exit(0);
}

int main(int argc, const char *argv[])
{
	IONotificationPortRef notify;
	io_object_t theIterator;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	if((root_port = IORegisterForSystemPower(0, &notify, powerchange_callback, &theIterator)) == nil)
	{
		[NSException raise: NSInternalInconsistencyException
			format: @"Failed to register process for System Power Notifications"];
	}

	CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notify), kCFRunLoopDefaultMode);

	signal(SIGTERM, sighandler);

	SecKeychainAddCallback(&keychain_locked, kSecLockEventMask, nil);
	SecKeychainAddCallback(&keychain_unlocked, kSecUnlockEventMask, nil);	

	[pool release];
	
	return NSApplicationMain(argc, argv);
}
