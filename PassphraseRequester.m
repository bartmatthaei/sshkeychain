/* $Id: PassphraseRequester.m,v 1.11 2003/11/28 13:09:34 bart Exp $ */

#import "Controller.h"

int main(int argc, const char *argv[])
{
	NSProcessInfo *procinfo;
	id UI;
	NSAutoreleasePool *pool;
	char *interaction;
	NSString *passphrase;

	if(argc == 2) 
	{
		procinfo = [NSProcessInfo processInfo];
		pool = [[NSAutoreleasePool alloc] init];

		UI = [NSConnection rootProxyForConnectionWithRegisteredName:@"SSHKeychain" host:NULL];

		if(UI == NULL) { 
			fprintf(stderr, "Can't connect to SSHKeychain\n"); 
			[pool release]; 
			exit(1); 
		}

		[UI setProtocolForProxy:@protocol(UI)];

		interaction = getenv("INTERACTION");

		if((interaction) && (strcmp(interaction, "1") == 0))
		{
			passphrase = [UI askPassphrase:[[procinfo arguments] objectAtIndex:1] withInteraction:YES];
			
			if(passphrase == NULL)
			{
				[pool release];
				exit(1);
			}
		}

		else
		{
			passphrase = [UI askPassphrase:[[procinfo arguments] objectAtIndex:1] withInteraction:NO];
			
			if(passphrase == NULL)
			{
				[pool release];
				exit(1);
			}
		}

		printf("%s\n", [passphrase cString]);

		[pool release];

		return 0;
	}

	return 1;
}
