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
