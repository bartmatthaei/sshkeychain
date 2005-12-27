#import <Foundation/Foundation.h>

@interface SSHAgent : NSObject 
{
	int thePid;
	int s;

	NSString *socketPath;
	NSString *agentSocketPath;

	NSArray *keysOnAgent;

	/* Locks */
	NSLock *socketPathLock;
	NSLock *agentSocketPathLock;
	NSLock *keysOnAgentLock;
	NSLock *thePidLock;
}

+ (id)currentAgent;

- (BOOL)setSocketPath:(NSString *)path;

- (NSString *)socketPath;
- (NSString *)agentSocketPath;

- (BOOL)start;
- (BOOL)stop;

- (BOOL)isRunning;
- (int)pid;
- (NSArray *)keysOnAgent;

- (void)closeSockets;

- (void)handleAgentConnections;
- (void)inputFromClient:(id)object;
- (void)checkAgent;

- (NSArray *)currentKeysOnAgent;

@end
