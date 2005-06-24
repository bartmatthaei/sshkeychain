/* $Id: TunnelRunner.c,v 1.1 2004/06/23 08:12:20 bart Exp $ */

#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/select.h>

#define BUFSIZE 4096

int child;

static void sighandler(int s)
{
	if(s != SIGCHLD)
	{
		if(child > 0) {
			kill(child, s);
		}

		signal(s, SIG_DFL);
		kill(getpid(), s);
	}
}

int main(int argc, char **argv)
{
	int i, r, devnull, status, p[2];
	char *em;
	char buf[BUFSIZE];

	buf[0] = '\0';

	if(argc < 2)
	{
		exit(1);
	}

	if(strstr(argv[1], "ssh") == NULL)
	{
		exit(1);
	}

	for(i=1; i < argc; i++) {
		argv[i-1] = argv[i];
		argv[i] = '\0';
	}

	/* Handle some signals. */
	signal(SIGCHLD, sighandler);

	signal(SIGKILL, sighandler);
	signal(SIGTERM, sighandler);
	signal(SIGALRM, sighandler);
	signal(SIGHUP, sighandler);
	signal(SIGINT, sighandler);
	signal(SIGQUIT, sighandler);
	signal(SIGPIPE, sighandler);
	signal(SIGTERM, sighandler);

	if(pipe(p) == -1)
	{
		em = strerror(errno);
		printf("pipe() failed (%s)\n", (em) ? em : "");
		return(-1);
	}
	
	child = fork();

	/* If the fork failed. */
	if(child == -1)
	{
		em = strerror(errno);
		printf("fork() failed (%s)\n", (em) ? em : "");
		return(-1);
	}

	/* If we're the child. */
	if(child == 0)
	{
		/* Close the read end of the pipe. */
		close(p[0]);

		/* Tie the write end of the pipe to stderr. */
		if(dup2(p[1], STDERR_FILENO) == -1)
		{
			em = strerror(errno);
			printf("dup2() failed (%s)\n", (em) ? em : "");
			exit(1);
		}

		/* We aren't interested in the stuff spewed to stdout. */
		if((devnull = open("/dev/null", O_WRONLY)) == -1)
		{
			em = strerror(errno);
			fprintf(stderr, "open failed : %s\n", (em)? em : "");
			exit(1);
		}

		/* Now direct stdout to our /dev/null filehandle. */
		if(dup2(devnull, STDOUT_FILENO) == -1)
		{
			em = strerror(errno);
			fprintf(stderr, "dup2() failed (%s)\n", (em) ? em : "");
			exit(1);
		}

		/* STDIN should block forever, so we tie it to the writ end of the pipe. */
		while(dup2(p[1], STDIN_FILENO) == -1)
		{
			em = strerror(errno);
			fprintf(stderr, "dup2() failed (%s)\n", (em) ? em : "");
			exit(1);
		}

		/* Execute ssh. */
		if(execv(argv[0], argv) == -1)
		{
			fprintf(stderr, "execv() failed (%s)\n", strerror(errno));
			exit(1);
		}

		/* We shouldn't reach this. */
		exit(1);
	}

	/* If we're the father (uh-oh). */
	if(child > 0)
	{
		/* Close the write end of the pipe. */
		close(p[1]);

		for(;;)
		{
			/* Read until we get EOF. */
			for(;;)
			{
				r = read(p[0], buf, BUFSIZE-1);

				if((r == -1) && (errno != EINTR))
				{
					em = strerror(errno);
					printf("read() failed : %s\n", (em) ? em : "");
					exit(1);
				}

				else if(r == 0)
				{
					/* We got EOF. Wait for ssh to exit. */
					while(waitpid(child, &status, 0) == -1)
					{
						if(errno == EINTR)
						{
							continue;
						}

						em = strerror(errno);
						printf("waitpid() failed (%s)\n", (em) ? em : "");
						exit(1);
					}

					exit(0);
				}

				else
				{
					buf[r] = '\0';

					if((strstr(buf, "Could not request")) && (strstr(buf, "forwarding")))
					{
						printf("tunnel failed\n");
						kill(child, SIGTERM);
					}
				}
			}
		}
	}

	return(0);
}
