%-----------------------------------------------------------------------------%
% Copyright (C) 1999-2002 The University of Melbourne.
% This file may only be copied under the terms of the GNU Library General
% Public License - see the file COPYING.LIB in the Mercury distribution.
%-----------------------------------------------------------------------------%
% File: declarative_user.m
% Author: Mark Brown
% Purpose:
% 	This module performs all the user interaction of the front
% end of the declarative debugger.  It is responsible for displaying
% questions and bugs in a human-readable format, and for getting
% responses to debugger queries from the user.
%

:- module mdb__declarative_user.
:- interface.
:- import_module mdb__declarative_debugger.
:- import_module list, io.

:- type user_response(T)
	--->	user_answer(decl_question(T), decl_answer(T))
	;	no_user_answer
	;	exit_diagnosis(T)
	;	abort_diagnosis.

:- type user_state.

:- pred user_state_init(io__input_stream, io__output_stream, user_state).
:- mode user_state_init(in, in, out) is det.

	% This predicate handles the interactive part of the declarative
	% debugging process.  The user is presented with an EDT node,
	% and is asked to respond about the truth of the node in the
	% intended interpretation.
	%
:- pred query_user(list(decl_question(T))::in, user_response(T)::out,
	user_state::in, user_state::out, io__state::di, io__state::uo)
	is cc_multi.

	% Confirm that the node found is indeed an e_bug or an i_bug.
	%
:- pred user_confirm_bug(decl_bug::in, decl_confirmation::out,
	user_state::in, user_state::out, io__state::di, io__state::uo)
	is cc_multi.

%-----------------------------------------------------------------------------%

:- implementation.
:- import_module mdb__browser_info, mdb__browse, mdb__io_action, mdb__util.
:- import_module mdb__declarative_execution, mdb__program_representation.
:- import_module std_util, char, string, bool, int, deconstruct.

:- type user_state
	--->	user(
			instr	:: io__input_stream,
			outstr	:: io__output_stream,
			browser	:: browser_persistent_state
		).

user_state_init(InStr, OutStr, User) :-
	browser_info__init_persistent_state(Browser),
	User = user(InStr, OutStr, Browser).

%-----------------------------------------------------------------------------%

query_user(Questions, Response, User0, User) -->
	query_user_2(Questions, [], Response, User0, User).

:- pred query_user_2(list(decl_question(T))::in, list(decl_question(T))::in,
	user_response(T)::out, user_state::in, user_state::out,
	io__state::di, io__state::uo) is cc_multi.

query_user_2([], _, no_user_answer, User, User) -->
	[].
query_user_2([Question | Questions], Skipped, Response, User0, User) -->
	write_decl_question(Question, User0),
	{ Node = get_decl_question_node(Question) },
	{ decl_question_prompt(Question, Prompt) },
	get_command(Prompt, Command, User0, User1),
	(
		{ Command = yes },
		{ Response = user_answer(Question, truth_value(Node, yes)) },
		{ User = User1 }
	;
		{ Command = no },
		{ Response = user_answer(Question, truth_value(Node, no)) },
		{ User = User1 }
	;
		{ Command = inadmissible },
		io__write_string("Sorry, not implemented,\n"),
		query_user_2([Question | Questions], Skipped, Response,
				User1, User)
	;
		{ Command = skip },
		query_user_2(Questions, [Question | Skipped], Response,
				User1, User)
	;
		{ Command = restart },
		{ reverse_and_append(Skipped, [Question | Questions],
				RestartedQuestions) },
		query_user(RestartedQuestions, Response, User1, User)
	;
		{ Command = browse_arg(ArgNum) },
		{ edt_node_trace_atom(Question, TraceAtom) },
		browse_atom_argument(TraceAtom, ArgNum, MaybeMark,
			User1, User2),
		(
			{ MaybeMark = no },
			query_user_2([Question | Questions], Skipped, Response,
					User2, User)
		;
			{ MaybeMark = yes(Mark) },
			{ Which = chosen_head_vars_presentation },
			{
				Which = only_user_headvars,
				ArgPos = user_head_var(ArgNum)
			;
				Which = all_headvars,
				ArgPos = any_head_var(ArgNum)
			},
			{ Answer = suspicious_subterm(Node, ArgPos, Mark) },
			{ Response = user_answer(Question, Answer) },
			{ User = User2 }
		)
	;
		{ Command = browse_io(ActionNum) },
		{ edt_node_io_actions(Question, IoActions) },
		% We don't have code yet to trace a marked I/O action.
		browse_chosen_io_action(IoActions, ActionNum, _MaybeMark,
			User1, User2),
		query_user_2([Question | Questions], Skipped, Response,
			User2, User)
	;
		{ Command = pd },
		{ Response = exit_diagnosis(Node) },
		{ User = User1 }
	;
		{ Command = abort },
		{ Response = abort_diagnosis },
		{ User = User1 }
	;
		{ Command = help },
		user_help_message(User1),
		query_user_2([Question | Questions], Skipped, Response,
				User1, User)
	;
		{ Command = illegal_command },
		io__write_string("Unknown command, 'h' for help.\n"),
		query_user_2([Question | Questions], Skipped, Response,
				User1, User)
	).

:- pred decl_question_prompt(decl_question(T), string).
:- mode decl_question_prompt(in, out) is det.

decl_question_prompt(wrong_answer(_, _), "Valid? ").
decl_question_prompt(missing_answer(_, _, _), "Complete? ").
decl_question_prompt(unexpected_exception(_, _, _), "Expected? ").

:- pred edt_node_trace_atom(decl_question(T)::in, trace_atom::out) is det.

edt_node_trace_atom(wrong_answer(_, FinalDeclAtom),
	FinalDeclAtom ^ final_atom).
edt_node_trace_atom(missing_answer(_, InitDeclAtom, _),
	InitDeclAtom ^ init_atom).
edt_node_trace_atom(unexpected_exception(_, InitDeclAtom, _),
	InitDeclAtom ^ init_atom).

:- pred edt_node_io_actions(decl_question(T)::in, list(io_action)::out) is det.

edt_node_io_actions(wrong_answer(_, FinalDeclAtom),
	FinalDeclAtom ^ final_io_actions).
edt_node_io_actions(missing_answer(_, _, _), []).
edt_node_io_actions(unexpected_exception(_, _, _), []).

:- pred decl_bug_trace_atom(decl_bug::in, trace_atom::out) is det.

decl_bug_trace_atom(e_bug(incorrect_contour(FinalDeclAtom, _, _)),
	FinalDeclAtom ^ final_atom).
decl_bug_trace_atom(e_bug(partially_uncovered_atom(InitDeclAtom, _)),
	InitDeclAtom ^ init_atom).
decl_bug_trace_atom(e_bug(unhandled_exception(InitDeclAtom, _, _)),
	InitDeclAtom ^ init_atom).
decl_bug_trace_atom(i_bug(inadmissible_call(_, _, InitDeclAtom, _)),
	InitDeclAtom ^ init_atom).

:- pred decl_bug_io_actions(decl_bug::in, list(io_action)::out) is det.

decl_bug_io_actions(e_bug(incorrect_contour(FinalDeclAtom, _, _)),
	FinalDeclAtom ^ final_io_actions).
decl_bug_io_actions(e_bug(partially_uncovered_atom(_, _)), []).
decl_bug_io_actions(e_bug(unhandled_exception(_, _, _)), []).
decl_bug_io_actions(i_bug(inadmissible_call(_, _, _, _)), []).

:- pred browse_chosen_io_action(list(io_action)::in, int::in,
	maybe(term_path)::out, user_state::in, user_state::out,
	io__state::di, io__state::uo) is cc_multi.

browse_chosen_io_action(IoActions, ActionNum, MaybeMark, User0, User) -->
	( { list__index1(IoActions, ActionNum, IoAction) } ->
		browse_io_action(IoAction, MaybeMark, User0, User)
	;
		io__write_string("No such IO action.\n"),
		{ MaybeMark = no },
		{ User = User0 }
	).

:- pred browse_io_action(io_action::in, maybe(term_path)::out,
	user_state::in, user_state::out, io__state::di, io__state::uo)
	is cc_multi.

browse_io_action(IoAction, MaybeMark, User0, User) -->
	{ io_action_to_synthetic_term(IoAction, ProcName, Args, IsFunc) },
	browse_synthetic(ProcName, Args, IsFunc, User0 ^ instr, User0 ^ outstr,
		MaybeDirs, User0 ^ browser, Browser),
	{ maybe_convert_dirs_to_path(MaybeDirs, MaybeMark) },
	{ User = User0 ^ browser := Browser }.

:- pred browse_decl_bug_arg(decl_bug::in, int::in,
	user_state::in, user_state::out, io__state::di, io__state::uo)
	is cc_multi.

browse_decl_bug_arg(Bug, ArgNum, User0, User) -->
	{ decl_bug_trace_atom(Bug, Atom) },
	browse_atom_argument(Atom, ArgNum, _, User0, User).

:- pred browse_atom_argument(trace_atom::in, int::in, maybe(term_path)::out,
	user_state::in, user_state::out, io__state::di, io__state::uo)
	is cc_multi.

browse_atom_argument(Atom, ArgNum, MaybeMark, User0, User) -->
	{ Atom = atom(_, _, Args0) },
	{ maybe_filter_headvars(chosen_head_vars_presentation, Args0, Args) },
	(
		{ list__index1(Args, ArgNum, ArgInfo) },
		{ ArgInfo = arg_info(_, _, MaybeArg) },
		{ MaybeArg = yes(Arg) }
	->
		browse(univ_value(Arg), User0 ^ instr, User0 ^ outstr,
			MaybeDirs, User0 ^ browser, Browser),
		{ maybe_convert_dirs_to_path(MaybeDirs, MaybeMark) },
		{ User = User0 ^ browser := Browser }
	;
		io__write_string(User ^ outstr, "Invalid argument number\n"),
		{ MaybeMark = no },
		{ User = User0 }
	).

:- pred maybe_convert_dirs_to_path(maybe(list(dir)), maybe(term_path)).
:- mode maybe_convert_dirs_to_path(in, out) is det.

maybe_convert_dirs_to_path(no, no).
maybe_convert_dirs_to_path(yes(Dirs), yes(TermPath)) :-
	convert_dirs_to_term_path(Dirs, TermPath).

	% Reverse the first argument and append the second to it.
	%
:- pred reverse_and_append(list(T), list(T), list(T)).
:- mode reverse_and_append(in, in, out) is det.

reverse_and_append([], Bs, Bs).
reverse_and_append([A | As], Bs, Cs) :-
	reverse_and_append(As, [A | Bs], Cs).

%-----------------------------------------------------------------------------%

:- type user_command
	--->	yes			% The node is correct.
	;	no			% The node is incorrect.
	;	inadmissible		% The node is inadmissible.
	;	skip			% The user has no answer.
	;	restart			% Ask the skipped questions again.
	;	browse_arg(int)		% Browse the nth argument before
					% answering.
	;	browse_io(int)		% Browse the nth IO action before
					% answering.
	;	pd			% Commence procedural debugging from
					% this point.
	;	abort			% Abort this diagnosis session.
	;	help			% Request help before answering.
	;	illegal_command.	% None of the above.

:- pred user_help_message(user_state, io__state, io__state).
:- mode user_help_message(in, di, uo) is det.

user_help_message(User) -->
	io__write_strings(User ^ outstr, [
		"According to the intended interpretation of the program,",
		" answer one of:\n",
		"\ty\tyes\t\tthe node is correct\n",
		"\tn\tno\t\tthe node is incorrect\n",
%		"\ti\tinadmissible\tthe input arguments are out of range\n",
		"\ts\tskip\t\tskip this question\n",
		"\tr\trestart\t\task the skipped questions again\n",
		"\tb <n>\tbrowse <n>\tbrowse the nth argument of the atom\n",
		"\t\tpd\t\tcommence procedural debugging from this point\n",
		"\ta\tabort\t\t",
			"abort this diagnosis session and return to mdb\n",
		"\th, ?\thelp\t\tthis help message\n"
	]).

:- pred user_confirm_bug_help(user_state, io__state, io__state).
:- mode user_confirm_bug_help(in, di, uo) is det.

user_confirm_bug_help(User) -->
	io__write_strings(User ^ outstr, [
		"Answer one of:\n",
		"\ty\tyes\t\tconfirm that the suspect is a bug\n",
		"\tn\tno\t\tdo not accept that the suspect is a bug\n",
%		"\tb\tbrowse\t\tbrowse the suspect\n",
		"\ta\tabort\t\t",
			"abort this diagnosis session and return to mdb\n",
		"\th, ?\thelp\t\tthis help message\n"
	]).

:- pred get_command(string, user_command, user_state, user_state,
		io__state, io__state).
:- mode get_command(in, out, in, out, di, uo) is det.

get_command(Prompt, Command, User, User) -->
	util__trace_getline(Prompt, Result, User ^ instr, User ^ outstr),
	(
		{ Result = ok(String) },
		{ Words = string__words(char__is_whitespace, String) },
		{
			Words = [CmdWord | CmdArgs],
			cmd_handler(CmdWord, CmdHandler),
			CommandPrime = CmdHandler(CmdArgs)
		->
			Command = CommandPrime
		;
			Command = illegal_command
		}
	;
		{ Result = error(Error) },
		{ io__error_message(Error, Msg) },
		io__write_string(User ^ outstr, Msg),
		io__nl(User ^ outstr),
		{ Command = abort }
	;
		{ Result = eof },
		{ Command = abort }
	).

:- pred cmd_handler(string, func(list(string)) = user_command).
:- mode cmd_handler(in, out((func(in) = out is semidet))) is semidet.

cmd_handler("y",	one_word_cmd(yes)).
cmd_handler("yes",	one_word_cmd(yes)).
cmd_handler("n",	one_word_cmd(no)).
cmd_handler("no",	one_word_cmd(no)).
cmd_handler("in",	one_word_cmd(inadmissible)).
cmd_handler("inadmissible", one_word_cmd(inadmissible)).
cmd_handler("io",	browse_io_cmd).
cmd_handler("s",	one_word_cmd(skip)).
cmd_handler("skip",	one_word_cmd(skip)).
cmd_handler("r",	one_word_cmd(restart)).
cmd_handler("restart",	one_word_cmd(restart)).
cmd_handler("pd",	one_word_cmd(pd)).
cmd_handler("a",	one_word_cmd(abort)).
cmd_handler("abort",	one_word_cmd(abort)).
cmd_handler("?",	one_word_cmd(help)).
cmd_handler("h",	one_word_cmd(help)).
cmd_handler("help",	one_word_cmd(help)).
cmd_handler("b",	browse_arg_cmd).
cmd_handler("browse",	browse_arg_cmd).

:- func one_word_cmd(user_command::in, list(string)::in) = (user_command::out)
	is semidet.

one_word_cmd(Cmd, []) = Cmd.

:- func browse_arg_cmd(list(string)::in) = (user_command::out) is semidet.

browse_arg_cmd([Arg]) = browse_arg(ArgNum) :-
	string__to_int(Arg, ArgNum).

:- func browse_io_cmd(list(string)::in) = (user_command::out) is semidet.

browse_io_cmd([Arg]) = browse_io(ArgNum) :-
	string__to_int(Arg, ArgNum).

%-----------------------------------------------------------------------------%

user_confirm_bug(Bug, Response, User0, User) -->
	write_decl_bug(Bug, User0),
	get_command("Is this a bug? ", Command, User0, User1),
	(
		{ Command = yes }
	->
		{ Response = confirm_bug },
		{ User = User1 }
	;
		{ Command = no }
	->
		{ Response = overrule_bug },
		{ User = User1 }
	;
		{ Command = abort }
	->
		{ Response = abort_diagnosis },
		{ User = User1 }
	;
		{ Command = browse_arg(ArgNum) }
	->
		browse_decl_bug_arg(Bug, ArgNum, User1, User2),
		user_confirm_bug(Bug, Response, User2, User)
	;
		{ Command = browse_io(ActionNum) }
	->
		{ decl_bug_io_actions(Bug, IoActions) },
		browse_chosen_io_action(IoActions, ActionNum, _MaybeMark,
			User1, User2),
		user_confirm_bug(Bug, Response, User2, User)
	;
		user_confirm_bug_help(User1),
		user_confirm_bug(Bug, Response, User1, User)
	).

%-----------------------------------------------------------------------------%

	% Display the node in user readable form on the current
	% output stream.
	%
:- pred write_decl_question(decl_question(T)::in, user_state::in,
	io__state::di, io__state::uo) is cc_multi.

write_decl_question(wrong_answer(_, Atom), User) -->
	write_decl_final_atom(User, "", print, Atom).
	
write_decl_question(missing_answer(_, Call, Solns), User) -->
	write_decl_init_atom(User, "Call ", print, Call),
	(
		{ Solns = [] }
	->
		io__write_string(User ^ outstr, "No solutions.\n")
	;
		io__write_string(User ^ outstr, "Solutions:\n"),
		list__foldl(write_decl_final_atom(User, "\t", print_all), Solns)
	).

write_decl_question(unexpected_exception(_, Call, Exception), User) -->
	write_decl_init_atom(User, "Call ", print, Call),
	io__write_string(User ^ outstr, "Throws "),
	io__write(User ^ outstr, include_details_cc, univ_value(Exception)),
	io__nl(User ^ outstr).

:- pred write_decl_bug(decl_bug::in, user_state::in,
	io__state::di, io__state::uo) is cc_multi.

write_decl_bug(e_bug(EBug), User) -->
	(
		{ EBug = incorrect_contour(Atom, _, _) },
		io__write_string(User ^ outstr, "Found incorrect contour:\n"),
		write_decl_final_atom(User, "", print, Atom)
	;
		{ EBug = partially_uncovered_atom(Atom, _) },
		io__write_string(User ^ outstr,
				"Found partially uncovered atom:\n"),
		write_decl_init_atom(User, "", print, Atom)
	;
		{ EBug = unhandled_exception(Atom, Exception, _) },
		io__write_string(User ^ outstr, "Found unhandled exception:\n"),
		write_decl_init_atom(User, "", print, Atom),
		io__write(User ^ outstr, include_details_cc,
				univ_value(Exception)),
		io__nl(User ^ outstr)
	).

write_decl_bug(i_bug(IBug), User) -->
	{ IBug = inadmissible_call(Parent, _, Call, _) },
	io__write_string(User ^ outstr, "Found inadmissible call:\n"),
	write_decl_atom(User, "Parent ", print, init(Parent)),
	write_decl_atom(User, "Call ", print, init(Call)).

:- pred write_decl_init_atom(user_state::in, string::in, browse_caller_type::in,
	init_decl_atom::in, io__state::di, io__state::uo) is cc_multi.

write_decl_init_atom(User, Indent, CallerType, InitAtom) -->
	write_decl_atom(User, Indent, CallerType, init(InitAtom)).

:- pred write_decl_final_atom(user_state::in, string::in,
	browse_caller_type::in, final_decl_atom::in, io__state::di,
	io__state::uo) is cc_multi.

write_decl_final_atom(User, Indent, CallerType, FinalAtom) -->
	write_decl_atom(User, Indent, CallerType, final(FinalAtom)).

:- pred write_decl_atom(user_state::in, string::in, browse_caller_type::in,
	some_decl_atom::in, io__state::di, io__state::uo) is cc_multi.

write_decl_atom(User, Indent, CallerType, DeclAtom) -->
	io__write_string(User ^ outstr, Indent),
	{ unravel_decl_atom(DeclAtom, TraceAtom, IoActions) },
	{ TraceAtom = atom(PredOrFunc, Functor, Args0) },
	{ Which = chosen_head_vars_presentation },
	{ maybe_filter_headvars(Which, Args0, Args1) },
	{ list__map(trace_atom_arg_to_univ, Args1, Args) },
		%
		% Call the term browser to print the atom (or part of it
		% up to a size limit) as a goal.
		%
	browse__print_synthetic(Functor, Args, is_function(PredOrFunc),
		User ^ outstr, CallerType, User ^ browser),
	write_io_actions(User, IoActions).

:- pred trace_atom_arg_to_univ(trace_atom_arg::in, univ::out) is det.

trace_atom_arg_to_univ(TraceAtomArg, Univ) :-
	MaybeUniv = TraceAtomArg ^ arg_value,
	(
		MaybeUniv = yes(Univ)
	;
		MaybeUniv = no,
		Univ = univ('_' `with_type` unbound)
	).

:- pred write_io_actions(user_state::in, list(io_action)::in, io__state::di,
	io__state::uo) is cc_multi.

write_io_actions(User, IoActions) -->
	{ list__length(IoActions, NumIoActions) },
	( { NumIoActions = 0 } ->
		[]
	;
		( { NumIoActions = 1 } ->
			io__write_string(User ^ outstr, "1 io action:")
		;
			io__write_int(User ^ outstr, NumIoActions),
			io__write_string(User ^ outstr, " io actions:")
		),
		% XXX the 6 should be configurable
 		( { NumIoActions < 6 } ->
			io__nl(User ^ outstr),
			list__foldl(print_io_action(User), IoActions)
		;
			io__write_string(User ^ outstr, " too many to show"),
			io__nl(User ^ outstr)
		)
	).

:- pred print_io_action(user_state::in, io_action::in,
	io__state::di, io__state::uo) is cc_multi.

print_io_action(User, IoAction) -->
	{ io_action_to_synthetic_term(IoAction, ProcName, Args, IsFunc) },
	browse__print_synthetic(ProcName, Args, IsFunc, User ^ outstr,
		print_all, User ^ browser).

%-----------------------------------------------------------------------------%
