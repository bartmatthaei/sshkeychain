#import <Foundation/Foundation.h>

#import "SSHKey.h"

@interface SSHKeychain : NSObject 
{
	NSMutableArray *keychain;

	NSString *agentSocketPath;
	BOOL addingKeys;
	
	int lastAdded;

	/* Locks */
	NSLock *keychainLock;
	NSLock *addingKeysLock;
	NSLock *lastAddedLock;
}

+ (id)currentKeychain;
+ (id)keychainWithPaths:(NSArray *)thePaths;

- (id)initWithPaths:(NSArray *)paths;
- (void)resetToKeysWithPaths:(NSArray *)paths;

- (BOOL)addingKeys;

- (void)setAgentSocketPath:(NSString *)path;

- (SSHKey *)keyAtIndex:(int)nr;

- (BOOL)removeKeyAtIndex:(int)nr;

- (BOOL)addKey:(SSHKey *)key;
- (BOOL)addKeyWithPath:(NSString *)path;

- (NSMutableArray *)arrayOfPaths;
- (int)count;

- (BOOL)addKeysToAgent;
- (BOOL)addKeysToAgentWithInteraction:(BOOL)interaction;
- (void)removeKeysAfterTimeout:(id)object;
- (BOOL)removeKeysFromAgent;

@end
