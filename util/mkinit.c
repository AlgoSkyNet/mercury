/*---------------------------------------------------------------------------*/

/*
** Copyright (C) 1995 University of Melbourne.
** This file may only be copied under the terms of the GNU General
** Public License - see the file COPYING in the Mercury distribution.
*/

/*
** File: mkinit.c
** Main authors: zs, fjh
**
** Given a list of .c or .init files on the command line, this program
** produces the initialization file (usually called *_init.c) on stdout.
** The initialization file is a small C program that calls the initialization
** functions for all the modules in a Mercury program.
*/

/*---------------------------------------------------------------------------*/

#include	<stdio.h>
#include	<stdlib.h>
#include	<string.h>
#include	<ctype.h>
#include	<errno.h>
#include	"getopt.h"
#include	"conf.h"

/* --- adjustable limits --- */
#define	MAXCALLS	40	/* maximum number of calls per function */
#define	MAXLINE		256	/* maximum number of characters per line */
				/* (characters after this limit are ignored) */

/* --- global variables --- */

static const char *progname = NULL;

/* options and arguments, set by parse_options() */
static const char *entry_point = "mercury__io__run_0_0";
static int maxcalls = MAXCALLS;
static int num_files;
static char **files;

static int num_modules = 0;
static int num_errors = 0;

/* --- code fragments to put in the output file --- */
static const char header1[] = 
	"/*\n"
	"** This code automatically generated by mkinit - do not edit.\n"
	"**\n"
	"** Input files:\n"
	"**\n"
	;

static const char header2[] = 
	"*/\n"
	"\n"
	"#include <stddef.h>\n"
	"#include \"init.h\"\n"
	"\n"
	"/*\n"
	"** Work around a bug in the Solaris 2.X (X<=4) linker;\n"
	"** on these machines, init_gc must be statically linked.\n"
	"*/\n"
	"\n"
	"#ifdef CONSERVATIVE_GC\n"
	"static void init_gc(void)\n"
	"{\n"
	"	GC_INIT();\n"
	"}\n"
	"#endif\n"
	"\n"
	;

static const char main_func[] =
	"Declare_entry(%s);\n"
	"\n"
	"int main(int argc, char **argv)\n"
	"{\n"
	"\n"
	"#ifdef CONSERVATIVE_GC\n"
	"	/*\n"
	"	** Explicitly register the bottom of the stack, so that the\n"
	"	** GC knows where it starts.  This is necessary for AIX 4.1\n"
	"	**  on RS/6000; it may also be helpful on other systems.\n"
	"	*/\n"
	"	{ char dummy;\n"
	"	  extern char *GC_stackbottom;\n"
	"	  GC_stackbottom = &dummy;\n"
	"	}\n"
	"#endif\n"
	"\n"
	"	address_of_mercury_init_io = mercury_init_io;\n"
	"	address_of_init_modules = init_modules;\n"
	"#ifdef CONSERVATIVE_GC\n"
	"	address_of_init_gc = init_gc;\n"
	"#endif\n"
	"#if defined(USE_GCC_NONLOCAL_GOTOS) && !defined(USE_ASM_LABELS)\n"
	"	do_init_modules();\n"
	"#endif\n"
	"	program_entry_point = ENTRY(mercury__main_2_0);\n"
	"	library_entry_point = ENTRY(%s);\n"
	"\n"
	"	return mercury_main(argc, argv);\n"
	"}\n"
	"\n"
	;

/* --- function prototypes --- */
static	void parse_options(int argc, char *argv[]);
static	void usage(void);
static	void output_headers(void);
static	void output_sub_init_functions(void);
static	void output_main_init_function(void);
static	void output_main(void);
static	void process_file(char *filename);
static	void process_init_file(const char *filename);
static	void output_init_function(const char *func_name);
static	int getline(FILE *file, char *line, int line_max);

/*---------------------------------------------------------------------------*/

#ifndef HAVE_STRERROR

/*
** Apparently SunOS 4.1.3 doesn't have strerror()
**	(!%^&!^% non-ANSI systems, grumble...)
**
** This code is duplicated in runtime/prof.c.
*/

extern int sys_nerr;
extern char *sys_errlist[];

char *strerror(int errnum) {
	if (errnum >= 0 && errnum < sys_nerr && sys_errlist[errnum] != NULL) {
		return sys_errlist[errnum];
	} else {
		static char buf[30];
		sprintf(buf, "Error %d", errnum);
		return buf;
	}
}

#endif

/*---------------------------------------------------------------------------*/

int main(int argc, char **argv)
{
	progname = argv[0];

	parse_options(argc, argv);

	output_headers();
	output_sub_init_functions();
	output_main_init_function();
	output_main();

	if (num_errors > 0)
	{
		fputs("/* Force syntax error, since there were */\n", stdout);
		fputs("/* errors in the generation of this file */\n", stdout);
		fputs("#error \"You need to remake this file\"\n", stdout);
		exit(1);
	}

	exit(0);
}

/*---------------------------------------------------------------------------*/

static void parse_options(int argc, char *argv[])
{
	int	c;
	while ((c = getopt(argc, argv, "c:w:")) != EOF)
	{
		switch (c)
		{

	case 'c':	if (sscanf(optarg, "%d", &maxcalls) != 1)
				usage();
			break;

	case 'w':	entry_point = optarg;
			break;

	default:	usage();

		}
	}
	num_files = argc - optind;
	if (num_files <= 0)
		usage();
	files = argv + optind;
}

static void usage(void)
{
	fprintf(stderr, "Usage: mkinit [-c maxcalls] [-w entry] files...\n");
	exit(1);
}

/*---------------------------------------------------------------------------*/

static void output_headers(void)
{
	int filenum;

	fputs(header1, stdout);

	for (filenum = 0; filenum < num_files; filenum++)
	{
		fputs("** ", stdout);
		fputs(files[filenum], stdout);
		putc('\n', stdout);
	}

	fputs(header2, stdout);
}

static void output_sub_init_functions(void)
{
	int filenum;

	fputs("#if (defined(USE_GCC_NONLOCAL_GOTOS) && "
		"!defined(USE_ASM_LABELS)) \\\n", stdout);
	fputs("\t|| defined(PROFILE_CALLS) || defined(DEBUG_GOTOS) \\\n",
		stdout);
	fputs("\t|| defined(DEBUG_LABELS) || !defined(SPEED)\n\n", stdout);

	fputs("static void init_modules_0(void)\n", stdout);
	fputs("{\n", stdout);

	for (filenum = 0; filenum < num_files; filenum++)
	{
		process_file(files[filenum]);
	}

	fputs("}\n", stdout);
	fputs("\n#endif\n\n", stdout);
}

static void output_main_init_function(void)
{
	int i;

	fputs("static void init_modules(void)\n", stdout);
	fputs("{\n", stdout);

	fputs("#if (defined(USE_GCC_NONLOCAL_GOTOS) && "
		"!defined(USE_ASM_LABELS)) \\\n", stdout);
	fputs("\t|| defined(PROFILE_CALLS) || defined(DEBUG_GOTOS) \\\n",
		stdout);
	fputs("\t|| defined(DEBUG_LABELS) || !defined(SPEED)\n\n", stdout);
	for (i = 0; i <= num_modules; i++)
		printf("\tinit_modules_%d();\n", i);
	fputs("#endif\n", stdout);

	fputs("}\n", stdout);
}

static void output_main(void)
{
	printf(main_func, entry_point, entry_point);
}

/*---------------------------------------------------------------------------*/

static void process_file(char *filename) {
	int len = strlen(filename);
	if (strcmp(filename + len - 2, ".m") == 0) {
		char func_name[1000];
		filename[len - 2] = '\0';	 /* remove trailing ".m" */
		sprintf(func_name, "mercury__%s__init", filename);
		output_init_function(func_name);
	} else if (strcmp(filename + len - 5, ".init") == 0) {
		process_init_file(filename);
	} else if (strcmp(filename + len - 2, ".c") == 0) {
		process_init_file(filename);
	} else {
		fprintf(stderr,
			"%s: filename `%s' must end in `.m', `.c' or `.init'\n",
			progname, filename);
		num_errors++;
	}
}

static void process_init_file(const char *filename) {
	const char * const	init_str = "INIT ";
	const char * const	endinit_str = "ENDINIT ";
	const int		init_strlen = strlen(init_str);
	const int		endinit_strlen = strlen(endinit_str);
	char			line[MAXLINE];
	FILE *			cfile;

	cfile = fopen(filename, "r");
	if (cfile == NULL)
	{
		fprintf(stderr, "%s: error opening file `%s': %s\n",
			progname, filename, strerror(errno));
		num_errors++;
		return;
	}

	while (getline(cfile, line, MAXLINE) > 0)
	{
		if (strncmp(line, init_str, init_strlen) == 0)
		{
			int	j;

			for (j = init_strlen; isalnum(line[j]) ||
						line[j] == '_'; j++)
				;
			line[j] = '\0';

			output_init_function(line+init_strlen);
		}

		if (strncmp(line, endinit_str, endinit_strlen) == 0)
			break;
	}

	fclose(cfile);
}

static void output_init_function(const char *func_name)
{
	static int num_calls = 0;

	if (num_calls >= maxcalls)
	{
		printf("}\n\n");

		num_modules++;
		num_calls = 0;
		printf("static void init_modules_%d(void)\n", num_modules);
		printf("{\n");
	}

	num_calls++;

	printf("\t{ extern void %s(void);\n", func_name);
	printf("\t  %s(); }\n", func_name);
}

/*---------------------------------------------------------------------------*/

static int getline(FILE *file, char *line, int line_max)
{
	int	c, num_chars, limit;

	num_chars = 0;
	limit = line_max - 2;
	while ((c = getc(file)) != EOF && c != '\n')
		if (num_chars < limit)
			line[num_chars++] = c;
	
	if (c == '\n' || num_chars > 0)
		line[num_chars++] = '\n';

	line[num_chars] = '\0';
	return num_chars;
}

/*---------------------------------------------------------------------------*/
