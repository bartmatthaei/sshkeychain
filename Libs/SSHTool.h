#import <Foundation/Foundation.h>

@interface SSHTool : NSObject 
{
	NSTask *task;
	NSString *toolPath;
	BOOL waitUntilExit;
	
	SEL terminateSelector;
	id terminateObject;
	id terminateInfo;
}

+ (id)toolWithName:(NSString *)toolname;
+ (id)toolWithPath:(NSString *)path;

- (NSTask *)task;

- (void)setPath:(NSString *)path;
- (void)setArgument:(NSString *)argument;
- (void)setArguments:(NSArray *)arguments;
- (void)setEnvironmentVariable:(NSString *)variable withValue:(NSString *)value;

- (NSString *)launchForStandardOutput;
- (BOOL)launchAndWait;
- (BOOL)launch;
- (void)terminate;

- (void)handleTerminateWithSelector:(SEL)theSelector toObject:(id)theObject withInfo:(id)theInfo;

@end
