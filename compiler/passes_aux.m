%-----------------------------------------------------------------------------%
% Copyright (C) 1995 University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%

% Author: zs

% This file contains auxiliary routines for the passes of the front and back
% ends of the compiler.

:- module passes_aux.

:- interface.

:- import_module string, io.
:- import_module hlds.

:- pred write_progress_message(string, pred_id, module_info,
	io__state, io__state).
:- mode write_progress_message(in, in, in, di, uo) is det.

:- implementation.

:- import_module bool, std_util.
:- import_module options, globals, hlds_out.

write_progress_message(Message, PredId, ModuleInfo) -->
	globals__io_lookup_bool_option(very_verbose, VeryVerbose),
	( { VeryVerbose = yes } ->
		io__write_string(Message),
		hlds_out__write_pred_id(ModuleInfo, PredId),
		io__write_string("\n")
	;
		[]
	).

% :- pred maybe_report_stats(bool::in, io__state::di, io__state::uo) is det.
% :- pred maybe_write_string(bool::input, string::input,
% 	io__state::di, io__state::uo) is det.
% :- pred maybe_flush_output(bool::in, io__state::di, io__state::uo) is det.
% 
% maybe_report_stats(yes) --> io__report_stats.
% maybe_report_stats(no) --> [].
% 
% maybe_write_string(yes, String) --> io__write_string(String).
% maybe_write_string(no, _) --> [].
% 
% maybe_flush_output(yes) --> io__flush_output.
% maybe_flush_output(no) --> [].
