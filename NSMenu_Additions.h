//
//  NSMenu_Additions.h
//  SSHKeychain
//
//  Created by Kevin Ballard on 12/8/04.
//  Copyright 2004 Kevin Ballard. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSMenu (NSMenu_Additions)
- (id <NSMenuItem>) itemWithRepresentation:(id)rep;
@end
