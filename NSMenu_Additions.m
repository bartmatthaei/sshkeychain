//
//  NSMenu_Additions.m
//  SSHKeychain
//
//  Created by Kevin Ballard on 12/8/04.
//  Copyright 2004 Kevin Ballard. All rights reserved.
//

#import "NSMenu_Additions.h"

@implementation NSMenu (NSMenu_Additions)
- (id <NSMenuItem>) itemWithRepresentation:(id)rep {
	NSArray *items = [self itemArray];
	NSEnumerator *e = [items objectEnumerator];
	id <NSMenuItem> anItem;
	while (anItem = [e nextObject]) {
		if ([[anItem representedObject] isEqual:rep]) {
			return anItem;
		}
	}
	return nil;
}
@end
