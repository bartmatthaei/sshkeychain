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

		UI = [NSConnection rootProxyForConnectionWithRegisteredName:@"SSHKeychain" host:nil];

		if(UI == nil) { 
			fprintf(stderr, "Can't connect to SSHKeychain\n"); 
			[pool release]; 
			exit(1); 
		}

		[UI setProtocolForProxy:@protocol(UI)];

		interaction = getenv("INTERACTION");

		if((interaction) && (strcmp(interaction, "1") == 0))
		{
			passphrase = [UI askPassphrase:[[procinfo arguments] objectAtIndex:1] withInteraction:YES];
			
			if(passphrase == nil)
			{
				[pool release];
				exit(1);
			}
		}

		else
		{
			passphrase = [UI askPassphrase:[[procinfo arguments] objectAtIndex:1] withInteraction:NO];
			
			if(passphrase == nil)
			{
				[pool release];
				exit(1);
			}
		}

		printf("%s\n", [passphrase UTF8String]);

		[pool release];

		return 0;
	}

	return 1;
}
