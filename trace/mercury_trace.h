/*
** Copyright (C) 1997-1999 The University of Melbourne.
** This file may only be copied under the terms of the GNU Library General
** Public License - see the file COPYING.LIB in the Mercury distribution.
*/

/*
** mercury_trace.h defines the interface by which the internal and external
** debuggers can control how the tracing subsystem treats events.
**
** The macros, functions and variables of this module are intended to be
** referred to only from code generated by the Mercury compiler, and from
** hand-written code in the Mercury runtime or the Mercury standard library,
** and even then only if at least some part of the program was compiled
** with some form of execution tracing.
**
** The parts of the tracing system that need to be present even when tracing
** is not enabled are in the module runtime/mercury_trace_base.
*/

#ifndef MERCURY_TRACE_H
#define MERCURY_TRACE_H

/*
** MR_Event_Info is used to hold the information for a trace event.  One
** of these is built by MR_trace_event and is passed (by reference)
** throughout the tracing system.
*/

typedef struct MR_Event_Info_Struct {
	Unsigned			MR_event_number;
	Unsigned			MR_call_seqno;
	Unsigned			MR_call_depth;
	MR_Trace_Port			MR_trace_port;
	const MR_Stack_Layout_Label	*MR_event_sll;
	const char 			*MR_event_path;
	Word				MR_saved_regs[MAX_FAKE_REG];
	int				MR_max_mr_num;
} MR_Event_Info;

/*
** MR_Event_Details is used to save some globals across calls to
** MR_trace_debug_cmd.  It is passed to MR_trace_retry which can
** then override the saved values.
*/

typedef struct MR_Event_Details_Struct {
	int			MR_call_seqno;
	int			MR_call_depth;
	int			MR_event_number;
} MR_Event_Details;

/* The initial size of arrays of argument values. */
#define	MR_INIT_ARG_COUNT	20

const char *	MR_trace_retry(MR_Event_Info *event_info,
			MR_Event_Details *event_details, Code **jumpaddr);
Word		MR_trace_find_input_arg(const MR_Stack_Layout_Label *label, 
			Word *saved_regs, const char *name, bool *succeeded);

/*
** MR_trace_cmd says what mode the tracer is in, i.e. how events should be
** treated.
**
** If MR_trace_cmd == MR_CMD_GOTO, the event handler will stop at the next
** event whose event number is equal to or greater than MR_trace_stop_event.
**
** If MR_trace_cmd == MR_CMD_FINISH, the event handler will stop at the next
** event that specifies the procedure invocation whose call number is in
** MR_trace_stop_seqno and whose port is EXIT or FAIL or EXCEPTION.
**
** If MR_trace_cmd == MR_CMD_RESUME_FORWARD, the event handler will stop at
** the next event of any call whose port is *not* REDO or FAIL or EXCEPTION.
**
** If MR_trace_cmd == MR_CMD_RETURN, the event handler will stop at
** the next event of any call whose port is *not* EXIT.
**
** If MR_trace_cmd == MR_CMD_MIN_DEPTH, the event handler will stop at
** the next event of any call whose depth is at least MR_trace_stop_depth.
**
** If MR_trace_cmd == MR_CMD_MAX_DEPTH, the event handler will stop at
** the next event of any call whose depth is at most MR_trace_stop_depth.
**
** If MR_trace_cmd == MR_CMD_TO_END, the event handler will not stop
** until the end of the program.
**
** If the event handler does not stop at an event, it will print the
** summary line for the event if MR_trace_print_intermediate is true.
*/

typedef enum {
	MR_CMD_GOTO,
	MR_CMD_FINISH,
	MR_CMD_RESUME_FORWARD,
	MR_CMD_RETURN,
	MR_CMD_MIN_DEPTH,
	MR_CMD_MAX_DEPTH,
	MR_CMD_TO_END
} MR_Trace_Cmd_Type;

typedef enum {
	MR_PRINT_LEVEL_NONE,	/* no events at all                        */
	MR_PRINT_LEVEL_SOME,	/* events matching an active spy point     */
	MR_PRINT_LEVEL_ALL	/* all events                              */
} MR_Trace_Print_Level;

typedef struct {
	MR_Trace_Cmd_Type	MR_trace_cmd;	
	Unsigned		MR_trace_stop_depth;	/* if MR_CMD_FINISH */
	Unsigned		MR_trace_stop_event;	/* if MR_CMD_GOTO   */
	MR_Trace_Print_Level	MR_trace_print_level;
	bool			MR_trace_strict;

				/*
				** The next field is an optimization;
				** it must be set to !MR_trace_strict ||
				** MR_trace_print_level != MR_PRINT_LEVEL_NONE
				*/
	bool			MR_trace_must_check;
} MR_Trace_Cmd_Info;

/*
** The different Mercury determinisms are internally represented by integers. 
** This array gives the correspondance with the internal representation and 
** the names that are usually used to denote determinisms.
*/

extern const char * MR_detism_names[];

#define	MR_port_is_final(port)		((port) == MR_PORT_EXIT || \
					 (port) == MR_PORT_FAIL || \
					 (port) == MR_PORT_EXCEPTION)

#define	MR_port_is_interface(port)	((port) < MR_PORT_FAIL || \
					 (port) == MR_PORT_EXCEPTION)

#define	MR_port_is_entry(port)		((port) == MR_PORT_CALL)

#endif /* MERCURY_TRACE_H */
