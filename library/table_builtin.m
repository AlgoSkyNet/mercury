%---------------------------------------------------------------------------%
% Copyright (C) 1998-2003 The University of Melbourne.
% This file may only be copied under the terms of the GNU Library General
% Public License - see the file COPYING.LIB in the Mercury distribution.
%---------------------------------------------------------------------------%

% File: table_builtin.m.
% Main authors: fjh, ohutch, zs.
% Stability: low.

% This file is automatically imported, as if via `use_module', into every
% module that contains a tabling pragma (`pragma memo', `pragma loopcheck',
% or `pragma minimal_model').  It is intended for the builtin procedures
% that the compiler generates implicit calls to when implementing tabling.
% This is separated from private_builtin.m, partly for modularity, but
% mostly to improve compilation speed for programs that don't use tabling.

% This module is a private part of the Mercury implementation;
% user modules should never explicitly import this module.
% The interface for this module does not get included in the
% Mercury library reference manual.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- module table_builtin.

%-----------------------------------------------------------------------------%

:- interface.

% This section of the module contains the predicates that are
% automatically inserted by the table_gen pass of the compiler
% into predicates that use tabling, and the types they use.
%
% The predicates fall into three categories:
%
% (1)	Predicates that manage the tabling of model_det and model_semi
%	predicates, whose evaluation method must be something other than
%	minimal model.
%
% (2)	Predicates that manage the tabling of model_non predicates,
%	whose evaluation method is usually minimal model.
%
% (3)	Utility predicates that are needed in the tabling of all predicates.
%
% The utility predicates that handle tries are combined lookup/insert
% operations; if the item being searched for is not already in the trie,
% they insert it. These predicates are used to implement both call tables,
% in which case the items inserted are input arguments of a tabled predicate,
% and answer tables, in which case the items inserted are output arguments
% of a tabled predicate.
%
% The call table trie is used for detecting duplicate calls,
% while the answer table trie is used for detecting duplicate answers.
% However, storing answers only in the answer table trie is not sufficient,
% for two reasons. First, while the trie encodes the values of the output
% arguments, this encoding is not in the form of the native Mercury
% representations of those arguments. Second, for model_non subgoals we
% want a chronological list of answers, to allow us to separate out
% answers we have returned already from answers we have not yet returned.
% To handle the first problem, we save each answer not only in the
% answer table trie but also in an answer block, which is a vector of N
% elements, where N is the number of output arguments of the procedure
% concerned. To handle the second problem, for model_non procedures
% we chain these answer blocks together in a chronological list.
%
% For simple goals, the word at the end of the call table trie is used
% first as a status indication (of type MR_SimpletableStatus), and later on
% as a pointer to an answer block (if the goal succeeded). This is OK, because
% we can distinguish the two, and because an answer block pointer can be
% associated with only one status value.
%
% For nondet goals, the word at the end of the call table trie always
% points to a subgoal structure, with several fields. The status of the
% subgoal and the list of answers are two of these fields. Other fields,
% described in runtime/mercury_tabling.h, are used in the implementation
% of the minimal model.
%
% All of the predicates here with the impure declaration modify the tabling
% structures. Because the structures are persistent through backtracking,
% this causes the predicates to become impure. The predicates with the semipure
% directive only examine the tabling structures, but do not modify them.
%
% At the moment, tabling is supported only by the LLDS and MLDS C backends,
% so in the next three type definitions, only the C definition is useful.
% The Mercury and IL definitions are placeholders only, required to make
% this module compile cleanly on the Java and .NET backends respectively.
%
% These three types ought to be abstract types. The only reason why their
% implementation is exported is that if they aren't, C code inside and
% outside the module would end up using different C types to represent
% values of these Mercury types, and lcc treats those type disagreements
% as errors.

	% This type represents the interior pointers of both call
	% tables and ansswer tables.
:- type ml_trie_node --->	ml_trie_node(c_pointer).
:- pragma foreign_type("C", ml_trie_node, "MR_TrieNode").
:- pragma foreign_type(il,  ml_trie_node, "class [mscorlib]System.Object").

	% This type represents the data structure at the tips of the call table
	% in model_non predicates.
:- type ml_subgoal --->		ml_subgoal(c_pointer).
:- pragma foreign_type("C", ml_subgoal, "MR_SubgoalPtr").
:- pragma foreign_type(il,  ml_subgoal, "class [mscorlib]System.Object").

	% This type represents a block of memory that contains one word
	% for each output argument of a procedure.
:- type ml_answer_block --->	ml_answer_block(c_pointer).
:- pragma foreign_type("C", ml_answer_block, "MR_AnswerBlock").
:- pragma foreign_type(il,  ml_answer_block, "class [mscorlib]System.Object").

:- implementation.

	% This type represents a list of answers of a model_non predicate.
:- type ml_answer_list --->	ml_answer_list(c_pointer).
:- pragma foreign_type("C", ml_answer_list, "MR_AnswerList").
:- pragma foreign_type(il,  ml_answer_list, "class [mscorlib]System.Object").

%-----------------------------------------------------------------------------%

:- interface.

%
% Predicates that manage the tabling of model_det and model_semi predicates.
%

	% Return true if the call represented by the given table has an
	% answer.
:- semipure pred table_simple_is_complete(ml_trie_node::in) is semidet.

	% Return true if the call represented by the given table has a
	% true answer.
:- semipure pred table_simple_has_succeeded(ml_trie_node::in) is semidet.

	% Return true if the call represented by the given table has
	% failed.
:- semipure pred table_simple_has_failed(ml_trie_node::in) is semidet.

	% Return true if the call represented by the given table is
	% currently being evaluated (working on an answer).
:- semipure pred table_simple_is_active(ml_trie_node::in) is semidet.

	% Return false if the call represented by the given table is
	% currently being evaluated (working on an answer).
:- semipure pred table_simple_is_inactive(ml_trie_node::in) is semidet.

	% Save the fact the the call has succeeded in the given table.
:- impure pred table_simple_mark_as_succeeded(ml_trie_node::in) is det.

	% Save the fact the the call has failed in the given table.
:- impure pred table_simple_mark_as_failed(ml_trie_node::in) is det.

	% Mark the call represented by the given table as currently
	% being evaluated (working on an answer).
:- impure pred table_simple_mark_as_active(ml_trie_node::in) is det.

	% Mark the call represented by the given table as currently
	% not being evaluated (working on an answer).
:- impure pred table_simple_mark_as_inactive(ml_trie_node::in) is det.

	% Return the answer block for the given call.
:- semipure pred table_simple_get_answer_block(ml_trie_node::in,
	ml_answer_block::out) is det.

	% N.B. interface continued below

%-----------------------------------------------------------------------------%

:- implementation.

:- pragma foreign_proc("C",
	table_simple_is_complete(T::in),
	[will_not_call_mercury],
"
#ifdef	MR_TABLE_DEBUG
	if (MR_tabledebug) {
		printf(""checking if simple %p is complete: %ld (%lx)\\n"",
			T, (long) T->MR_simpletable_status,
			(long) T->MR_simpletable_status);
	}
#endif
	SUCCESS_INDICATOR = 
		((T->MR_simpletable_status == MR_SIMPLETABLE_FAILED)
		|| (T->MR_simpletable_status >= MR_SIMPLETABLE_SUCCEEDED));
").

:- pragma foreign_proc("C",
	table_simple_has_succeeded(T::in),
	[will_not_call_mercury],
"
#ifdef	MR_TABLE_DEBUG
	if (MR_tabledebug) {
		printf(""checking if simple %p is succeeded: %ld (%lx)\\n"",
			T, (long) T->MR_simpletable_status,
			(long) T->MR_simpletable_status);
	}
#endif
	SUCCESS_INDICATOR =
		(T->MR_simpletable_status >= MR_SIMPLETABLE_SUCCEEDED);
").

:- pragma foreign_proc("C",
	table_simple_has_failed(T::in),
	[will_not_call_mercury],
"
#ifdef	MR_TABLE_DEBUG
	if (MR_tabledebug) {
		printf(""checking if simple %p is failed: %ld (%lx)\\n"",
			T, (long) T->MR_simpletable_status,
			(long) T->MR_simpletable_status);
	}
#endif
	SUCCESS_INDICATOR =
		(T->MR_simpletable_status == MR_SIMPLETABLE_FAILED);
").

:- pragma foreign_proc("C",
	table_simple_is_active(T::in),
	[will_not_call_mercury],
"
#ifdef	MR_TABLE_DEBUG
	if (MR_tabledebug) {
		printf(""checking if simple %p is active: %ld (%lx)\\n"",
			T, (long) T->MR_simpletable_status,
			(long) T->MR_simpletable_status);
	}
#endif
	SUCCESS_INDICATOR =
		(T->MR_simpletable_status == MR_SIMPLETABLE_WORKING);
").

:- pragma foreign_proc("C",
	table_simple_is_inactive(T::in),
	[will_not_call_mercury],
"
#ifdef	MR_TABLE_DEBUG
	if (MR_tabledebug) {
		printf(""checking if simple %p is inactive: %ld (%lx)\\n"",
			T, (long) T->MR_simpletable_status,
			(long) T->MR_simpletable_status);
	}
#endif
	SUCCESS_INDICATOR =
		(T->MR_simpletable_status != MR_SIMPLETABLE_WORKING);
").

:- pragma foreign_proc("C",
	table_simple_mark_as_succeeded(T::in),
	[will_not_call_mercury],
"
#ifdef	MR_TABLE_DEBUG
	if (MR_tabledebug) {
		printf(""marking %p as succeeded\\n"", T);
	}
#endif
	T->MR_simpletable_status = MR_SIMPLETABLE_SUCCEEDED;
").

:- pragma foreign_proc("C",
	table_simple_mark_as_failed(T::in),
	[will_not_call_mercury],
"
#ifdef	MR_TABLE_DEBUG
	if (MR_tabledebug) {
		printf(""marking %p as failed\\n"", T);
	}
#endif
	T->MR_simpletable_status = MR_SIMPLETABLE_FAILED;
").

:- pragma foreign_proc("C",
	table_simple_mark_as_active(T::in),
	[will_not_call_mercury],
"
#ifdef	MR_TABLE_DEBUG
	if (MR_tabledebug) {
		printf(""marking %p as working\\n"", T);
	}
#endif
	T->MR_simpletable_status = MR_SIMPLETABLE_WORKING;
").

:- pragma foreign_proc("C",
	table_simple_mark_as_inactive(T::in),
	[will_not_call_mercury],
"
#ifdef	MR_TABLE_DEBUG
	if (MR_tabledebug) {
		printf(""marking %p as uninitialized\\n"", T);
	}
#endif
	T->MR_simpletable_status = MR_SIMPLETABLE_UNINITIALIZED;
").

:- pragma foreign_proc("C",
	table_simple_get_answer_block(T::in, AB::out),
	[will_not_call_mercury, promise_semipure],
"
#ifdef	MR_TABLE_DEBUG
	if (MR_tabledebug) {
		printf(""getting answer block %p -> %p\\n"",
			T, T->MR_answerblock);
	}

	if (T->MR_simpletable_status <= MR_SIMPLETABLE_SUCCEEDED) {
		MR_fatal_error(""table_simple_get_answer_block: no block"");
	}
#endif
	AB = T->MR_answerblock;
").

:- pragma promise_semipure(table_simple_is_complete/1).
table_simple_is_complete(_) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_simple_is_complete").

:- pragma promise_semipure(table_simple_has_succeeded/1).
table_simple_has_succeeded(_) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_simple_has_succeeded").

:- pragma promise_semipure(table_simple_has_failed/1).
table_simple_has_failed(_) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_simple_has_failed").

:- pragma promise_semipure(table_simple_is_active/1).
table_simple_is_active(_) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_simple_is_active").

:- pragma promise_semipure(table_simple_is_inactive/1).
table_simple_is_inactive(_) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_simple_is_inactive").

table_simple_mark_as_succeeded(_) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_simple_mark_as_succeeded").

table_simple_mark_as_failed(_) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_simple_mark_as_failed").

table_simple_mark_as_active(_) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_simple_mark_as_active").

table_simple_mark_as_inactive(_) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_simple_mark_as_inactive").

:- pragma promise_semipure(table_simple_get_answer_block/2).
table_simple_get_answer_block(_, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_simple_get_answer_block").

%-----------------------------------------------------------------------------%

:- interface.

:- import_module io.

	% This procedure should be called exactly once for each I/O action.
	% If I/O tabling is enabled, this predicate will increment the I/O 
	% action counter, and will check if this action should be tabled.
	% If not, it fails. If yes, it succeeds, and binds the output
	% arguments, which are, in order:
	%
	% - The root trie node for all I/O actions. This is similar to
	%   the per-procedure tabling pointers, but it is shared by all
	%   I/O actions.
	% - the I/O action number of this action.
	% - The I/O action number of the first action in the tabled range.
	%
	% After the first tabled action, the root trie node will point to a
	% (dynamically expandable) array of trie nodes. The trie node for
	% I/O action number Counter is at offset Counter - Start in this array,
	% where Start is the I/O action number of the first tabled action.
	% The three output parameters together specify this location.

:- impure pred table_io_in_range(ml_trie_node::out, int::out, int::out)
	is semidet.

	% This procedure should be called exactly once for each I/O action
	% for which table_io_in_range returns true. Given the trie node
	% for a given I/O action number, it returns true iff that action has
	% been carried out before (i.e. the action is now being reexecuted
	% after a retry command in the debugger).

:- impure pred table_io_has_occurred(ml_trie_node::in) is semidet.

	% This predicate simply copies the input I/O state to become the output
	% I/O state. It is used only because it is easier to get the insts
	% right by calling this procedure than by hand-writing insts for a
	% unification.

:- pred table_io_copy_io_state(io__state::di, io__state::uo) is det.

	% Calls to these predicates bracket the code of foreign_procs with
	% the tabled_for_io_unitize annotation. The left bracket procedure
	% returns the current value of MR_trace_enabled, and then turns off
	% both MR_trace_enabled and MR_io_tabling_enabled. (We don't need to
	% save MR_io_tabling_enabled because we only get to this code if it
	% contains true.) The right bracket code takes the value returned by
	% the left bracket as input and restores both globals to the values
	% they had before the call to the left bracket.

:- impure pred table_io_left_bracket_unitized_goal(int::out) is det.
:- impure pred table_io_right_bracket_unitized_goal(int::in) is det.

	% N.B. interface continued below

%-----------------------------------------------------------------------------%

:- implementation.

% For purposes of I/O tabling, we divide the program's execution into four
% phases.
%
% Phase UNINIT consists of Mercury code executed prior to the first debugger
% event. Even if main/2 is traced, this will include the initialization of the
% I/O system itself. During this phase, MR_io_tabling_enabled will be MR_FALSE.
%
% Phase BEFORE consists of Mercury code during whose execution the user does
% not need safe retry across I/O, probably because he/she does not require
% retry at all. During this phase, MR_io_tabling_enabled will be MR_TRUE while
% we ensure that table_io_range returns MR_FALSE by setting MR_io_tabling_start
% to the highest possible value.
%
% Phase DURING consists of Mercury code during whose execution the user does
% need safe retry across I/O. During this phase, MR_io_tabling_enabled will be
% MR_TRUE, and MR_io_tabling_start will be set to the value of
% MR_io_tabling_counter on entry to phase DURING. We will ensure that
% table_io_in_range returns MR_TRUE by setting MR_io_tabling_end to the highest
% possible value.
%
% Phase AFTER again consists of Mercury code during whose execution the user
% does not need safe retry across I/O. During this phase, MR_io_tabling_enabled
% will be MR_TRUE, MR_io_tabling_start will contain the value of
% MR_io_tabling_counter at the time of the entry to phase DURING, while
% MR_io_tabling_end will contain the value of MR_io_tabling_counter at the end
% of phase DURING, thus ensuring that table_io_in_range again returns MR_FALSE.
%
% The transition from phase UNINIT to phase BEFORE will occur during the
% initialization of the debugger, at the first trace event.
%
% The transition from phase BEFORE to phase DURING will occur when the user
% issues the "table_io start" command, while the transition from phase DURING
% to phase AFTER will occur when the user issues the "table_io end" command.
% The user may automate entry into phase DURING by putting "table_io start"
% into a .mdbrc file. Of course the program will never enter phase DURING or
% phase AFTER if the user never gives the commands that start those phases.
%
% The debugger itself invokes Mercury code e.g. to print the values of
% variables. During such calls it will set MR_io_tabling_enabled to MR_FALSE,
% since the I/O actions executed during such times do not belong to the user
% program.

:- pragma foreign_decl("C", "
	#include ""mercury_trace_base.h""	/* for MR_io_tabling_* */
").

:- pragma foreign_proc("C",
	table_io_in_range(T::out, Counter::out, Start::out),
	[will_not_call_mercury],
"
	if (MR_io_tabling_enabled) {
		MR_Unsigned	old_counter;

#ifdef	MR_DEBUG_RETRY
		if (MR_io_tabling_debug) {
			printf(""checking table_io_in_range: ""
				""prev %d, start %d, hwm %d"",
				MR_io_tabling_counter, MR_io_tabling_start,
				MR_io_tabling_counter_hwm);
		}
#endif

		old_counter = MR_io_tabling_counter;

		MR_io_tabling_counter++;

		if (MR_io_tabling_start < MR_io_tabling_counter 
			&& MR_io_tabling_counter <= MR_io_tabling_end)
		{
			T = &MR_io_tabling_pointer;
			Counter = (MR_Word) old_counter;
			Start = MR_io_tabling_start;
			if (MR_io_tabling_counter > MR_io_tabling_counter_hwm)
			{
				MR_io_tabling_counter_hwm =
					MR_io_tabling_counter;
			}

#ifdef	MR_DEBUG_RETRY
			if (MR_io_tabling_debug) {
				printf("" in range\\n"");
			}
#endif

			SUCCESS_INDICATOR = MR_TRUE;
		} else {

#ifdef	MR_DEBUG_RETRY
			if (MR_io_tabling_debug) {
				printf("" not in range\\n"");
			}
#endif
			SUCCESS_INDICATOR = MR_FALSE;
		}
	} else {
		SUCCESS_INDICATOR = MR_FALSE;
	}
").

:- pragma foreign_proc("C",
	table_io_has_occurred(T::in),
	[will_not_call_mercury],
"
	MR_TrieNode	table;

	table = T;

#ifdef	MR_TABLE_DEBUG
	if (MR_tabledebug) {
		printf(""checking %p for previous execution: %p\\n"",
			table, table->MR_answerblock);
	}
#endif
	SUCCESS_INDICATOR = (table->MR_answerblock != NULL);
").

table_io_copy_io_state(IO, IO).

:- pragma foreign_proc("C",
	table_io_left_bracket_unitized_goal(TraceEnabled::out),
	[will_not_call_mercury],
"
	TraceEnabled = MR_trace_enabled;
	MR_trace_enabled = MR_FALSE;
	MR_io_tabling_enabled = MR_FALSE;
").

:- pragma foreign_proc("C",
	table_io_right_bracket_unitized_goal(TraceEnabled::in),
	[will_not_call_mercury],
"
	MR_io_tabling_enabled = MR_TRUE;
	MR_trace_enabled = TraceEnabled;
").

table_io_in_range(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_io_in_range").

table_io_has_occurred(_) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_io_has_occurred").

table_io_left_bracket_unitized_goal(_TraceEnabled) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_io_left_bracket_unitized_goal").

table_io_right_bracket_unitized_goal(_TraceEnabled) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_io_right_bracket_unitized_goal").

%-----------------------------------------------------------------------------%

:- interface.

%
% Predicates that manage the tabling of model_non subgoals.
%

	% Save the information that will be needed later about this
	% nondet subgoal in a data structure. If we have already seen
	% this subgoal before, do nothing.
:- impure pred table_nondet_setup(ml_trie_node::in, ml_subgoal::out) is det.

	% Save the state of the current subgoal and fail. Sometime later,
	% when the subgoal has some solutions, table_nondet_resume will
	% restore the saved state. At the time, table_nondet_suspend will
	% succeed, and return an answer block as its second argument.
:- impure pred table_nondet_suspend(ml_subgoal::in,
	ml_answer_block::out) is nondet.

	% Resume all suspended subgoal calls. This predicate will resume each
	% of the suspended subgoals that depend on it in turn until it reaches
	% a fixed point, at which all depended suspended subgoals have had
	% all available answers returned to them.
:- impure pred table_nondet_resume(ml_subgoal::in) is det.

	% Succeed if we have finished generating all answers for
	% the given nondet subgoal.
:- semipure pred table_nondet_is_complete(ml_subgoal::in) is semidet.

	% Succeed if the given nondet subgoal is active,
	% i.e. the process of computing all its answers is not yet complete.
:- semipure pred table_nondet_is_active(ml_subgoal::in) is semidet.

	% Mark a table as being active.
:- impure pred table_nondet_mark_as_active(ml_subgoal::in) is det.

	% Return the table of answers already returned to the given nondet
	% table.
:- impure pred table_nondet_get_ans_table(ml_subgoal::in, ml_trie_node::out)
	is det.

	% If the answer represented by the given answer table
	% has not been generated before by this subgoal,
	% succeed and remember the answer as having been generated.
	% If the answer has been generated before, fail.
:- impure pred table_nondet_answer_is_not_duplicate(ml_trie_node::in)
	is semidet.

	% Create a new slot in the answer list.
:- impure pred table_nondet_new_ans_slot(ml_subgoal::in, ml_trie_node::out)
	is det.

	% Return all of the answer blocks stored in the given table.
:- semipure pred table_nondet_return_all_ans(ml_subgoal::in,
	ml_answer_block::out) is nondet.
:- semipure pred table_multi_return_all_ans(ml_subgoal::in,
	ml_answer_block::out) is multi.

	% This type should correspond exactly to the type MR_SubgoalStatus
	% defined in runtime/mercury_tabling.h.

:- type subgoal_status
	--->	inactive
	;	active
	;	complete.

:- semipure pred table_subgoal_status(ml_subgoal::in, subgoal_status::out)
	is det.

	% N.B. interface continued below

%-----------------------------------------------------------------------------%

:- implementation.

:- pragma foreign_proc("C",
	table_nondet_setup(T::in, Subgoal::out),
	[will_not_call_mercury],
"
#ifndef	MR_USE_MINIMAL_MODEL
	MR_fatal_error(""minimal model code entered when not enabled"");
#else
#ifdef	MR_THREAD_SAFE
#error ""Sorry, not yet implemented: minimal model tabling with threads""
#endif
#ifdef	MR_HIGHLEVEL_CODE
#error ""Sorry, not yet implemented: minimal model tabling with high level code""
#endif
	/*
	** Initialize the subgoal if this is the first time we see it.
	** If the subgoal structure already exists but is marked inactive,
	** then it was left by a previous generator that couldn't
	** complete the evaluation of the subgoal due to a commit.
	** In that case, we want to forget all about the old generator.
	*/

	if (T->MR_subgoal == NULL) {
		MR_Subgoal	*subgoal;

		subgoal = MR_TABLE_NEW(MR_Subgoal);

		subgoal->MR_sg_back_ptr = T;
		subgoal->MR_sg_status = MR_SUBGOAL_INACTIVE;
		subgoal->MR_sg_leader = NULL;
		subgoal->MR_sg_followers = MR_TABLE_NEW(MR_SubgoalListNode);
		subgoal->MR_sg_followers->MR_sl_item = subgoal;
		subgoal->MR_sg_followers->MR_sl_next = NULL;
		subgoal->MR_sg_followers_tail =
			&(subgoal->MR_sg_followers->MR_sl_next);
		subgoal->MR_sg_answer_table.MR_integer = 0;
		subgoal->MR_sg_num_ans = 0;
		subgoal->MR_sg_answer_list = NULL;
		subgoal->MR_sg_answer_list_tail =
			&subgoal->MR_sg_answer_list;
		subgoal->MR_sg_consumer_list = NULL;
		subgoal->MR_sg_consumer_list_tail =
			&subgoal->MR_sg_consumer_list;

#ifdef	MR_TABLE_DEBUG
		/*
		** MR_subgoal_debug_cur_proc refers to the last procedure
		** that executed a call event, if any. If the procedure that is
		** executing table_nondet_setup is traced, this will be that
		** procedure, and recording the layout structure of the
		** processor in the subgoal allows us to interpret the contents
		** of the subgoal's answer tables. If the procedure executing
		** table_nondet_setup is not traced, then the layout structure
		** belongs to another procedure and the any use of the
		** MR_sg_proc_layout field will probably cause a core dump.
		** For implementors debugging minimal model tabling, this is
		** the right tradeoff.
		*/
		subgoal->MR_sg_proc_layout = MR_subgoal_debug_cur_proc;

		MR_enter_subgoal_debug(subgoal);

		if (MR_tabledebug) {
			printf(""setting up subgoal %p -> %s, "",
				T, MR_subgoal_addr_name(subgoal));
			printf(""answer slot %p\\n"",
				subgoal->MR_sg_answer_list_tail);
			if (subgoal->MR_sg_proc_layout != NULL) {
				printf(""proc: "");
				MR_print_proc_id(stdout,
					subgoal->MR_sg_proc_layout);
				printf(""\\n"");
			}
		}

		if (MR_maxfr != MR_curfr) {
			MR_fatal_error(
				""MR_maxfr != MR_curfr at table setup\\n"");
		}
#endif
		subgoal->MR_sg_generator_fr = MR_curfr;
		T->MR_subgoal = subgoal;
	}
	Subgoal = T->MR_subgoal;
#endif /* MR_USE_MINIMAL_MODEL */
").

table_nondet_setup(_, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_nondet_setup").

	% The definitions of these two predicates are in the runtime system,
	% in runtime/mercury_tabling.c.
:- external(table_nondet_suspend/2).
:- external(table_nondet_resume/1).

/*

XXX :- external stops us from using these two definitions

:- pragma foreign_proc("MC++",
	table_nondet_suspend(_A::in, _B::out), [will_not_call_mercury, promise_pure],
	local_vars(""),
	first_code(""),
	retry_code(""),
	common_code("
		mercury::runtime::Errors::SORRY(
			S""foreign code for this function"");
	")
).

:- pragma foreign_proc("MC++",
	table_nondet_resume(_A::in), [will_not_call_mercury, promise_pure], "
	mercury::runtime::Errors::SORRY(S""foreign code for this function"");
").

*/

:- pragma foreign_proc("C",
	table_nondet_is_complete(Subgoal::in),
	[will_not_call_mercury],
"
#ifdef	MR_USE_MINIMAL_MODEL
	SUCCESS_INDICATOR = (Subgoal->MR_sg_status == MR_SUBGOAL_COMPLETE);
#else
	MR_fatal_error(""minimal model code entered when not enabled"");
#endif
").

:- pragma foreign_proc("C",
	table_nondet_is_active(Subgoal::in),
	[will_not_call_mercury],
"
#ifdef	MR_USE_MINIMAL_MODEL
	SUCCESS_INDICATOR = (Subgoal->MR_sg_status == MR_SUBGOAL_ACTIVE);
#else
	MR_fatal_error(""minimal model code entered when not enabled"");
#endif
").

:- pragma foreign_proc("C",
	table_nondet_mark_as_active(Subgoal::in),
	[will_not_call_mercury],
"
#ifdef	MR_USE_MINIMAL_MODEL
	MR_push_generator(MR_curfr, Subgoal);
	MR_register_generator_ptr(Subgoal);
	Subgoal->MR_sg_status = MR_SUBGOAL_ACTIVE;
#else
	MR_fatal_error(""minimal model code entered when not enabled"");
#endif
").

:- pragma foreign_proc("C",
	table_nondet_get_ans_table(Subgoal::in, AT::out),
	[will_not_call_mercury],
"
#ifdef	MR_USE_MINIMAL_MODEL
  #ifdef MR_TABLE_DEBUG
	if (MR_tabledebug) {
		printf(""getting answer table %p -> %p\\n"",
			Subgoal, &(Subgoal->MR_sg_answer_table));
	}
  #endif
	AT = &(Subgoal->MR_sg_answer_table);
#else
	MR_fatal_error(""minimal model code entered when not enabled"");
#endif
").

:- pragma foreign_proc("C",
	table_nondet_answer_is_not_duplicate(T::in),
	[will_not_call_mercury],
"
#ifndef	MR_USE_MINIMAL_MODEL
	MR_fatal_error(""minimal model code entered when not enabled"");
#else
	MR_bool		is_new_answer;

#ifdef	MR_TABLE_DEBUG
	if (MR_tabledebug) {
		printf(""checking if %p is a duplicate answer: %ld\\n"",
			T, (long) T->MR_integer);
	}
#endif

	is_new_answer = (T->MR_integer == 0);
	T->MR_integer = 1;	/* any nonzero value will do */
	SUCCESS_INDICATOR = is_new_answer;
#endif
").

:- pragma foreign_proc("C",
	table_nondet_new_ans_slot(Subgoal::in, Slot::out),
	[will_not_call_mercury],
"
#ifndef	MR_USE_MINIMAL_MODEL
	MR_fatal_error(""minimal model code entered when not enabled"");
#else
	MR_AnswerListNode	*answer_node;

	Subgoal->MR_sg_num_ans++;

	/*
	**
	** We fill in the answer_data slot with a dummy value.
	** This slot will be filled in by the next piece of code
	** to be executed after we return, which is why we return its address.
	*/

	answer_node = MR_TABLE_NEW(MR_AnswerListNode);
	answer_node->MR_aln_answer_num = Subgoal->MR_sg_num_ans;
	answer_node->MR_aln_answer_data.MR_integer = 0;
	answer_node->MR_aln_next_answer = NULL;

#ifdef	MR_TABLE_DEBUG
	if (MR_tabledebug) {
		printf(""%s: new answer slot %d at %p(%p)\\n"",
			MR_subgoal_addr_name(Subgoal),
			Subgoal->MR_sg_num_ans, answer_node,
			&answer_node->MR_aln_answer_data);
		printf(""\tstoring into %p\\n"",
			Subgoal->MR_sg_answer_list_tail);
	}
#endif

	*(Subgoal->MR_sg_answer_list_tail) = answer_node;
	Subgoal->MR_sg_answer_list_tail = &(answer_node->MR_aln_next_answer);

	Slot = &(answer_node->MR_aln_answer_data);
#endif
").

table_nondet_return_all_ans(TrieNode, Answer) :-
	semipure pickup_answer_list(TrieNode, CurNode0),
	semipure table_nondet_return_all_ans_2(CurNode0, Answer).

table_multi_return_all_ans(TrieNode, Answer) :-
	semipure pickup_answer_list(TrieNode, CurNode0),
	( semipure return_next_answer(CurNode0, FirstAnswer, CurNode1) ->
		(
			Answer = FirstAnswer
		;
			semipure table_nondet_return_all_ans_2(CurNode1,
				Answer)
		)
	;
		error("table_multi_return_all_ans: no first answer")
	).

:- semipure pred table_nondet_return_all_ans_2(ml_answer_list::in,
	ml_answer_block::out) is nondet.

table_nondet_return_all_ans_2(CurNode0, Answer) :-
	semipure return_next_answer(CurNode0, FirstAnswer, CurNode1),
	(
		Answer = FirstAnswer
	;
		semipure table_nondet_return_all_ans_2(CurNode1, Answer)
	).

:- semipure pred pickup_answer_list(ml_subgoal::in, ml_answer_list::out)
	is det.

:- pragma foreign_proc("C",
	pickup_answer_list(Subgoal::in, CurNode::out),
	[will_not_call_mercury],
"
#ifdef MR_USE_MINIMAL_MODEL
	CurNode = Subgoal->MR_sg_answer_list;

  #ifdef MR_TABLE_DEBUG
	if (MR_tabledebug) {
		printf(""picking up all answers in %p -> %s\\n"",
			Subgoal->MR_sg_back_ptr,
			MR_subgoal_addr_name(Subgoal));
	}
  #endif
#else
	MR_fatal_error(""minimal model code entered when not enabled"");
#endif
").

:- semipure pred return_next_answer(ml_answer_list::in, ml_answer_block::out,
	ml_answer_list::out) is semidet.

:- pragma foreign_proc("C",
	return_next_answer(CurNode0::in, AnswerBlock::out, CurNode::out),
	[will_not_call_mercury],
"
#ifdef MR_USE_MINIMAL_MODEL
	if (CurNode0 == NULL) {
		SUCCESS_INDICATOR = MR_FALSE;
	} else {
		AnswerBlock = CurNode0->MR_aln_answer_data.MR_answerblock;
		CurNode = CurNode0->MR_aln_next_answer;
		SUCCESS_INDICATOR = MR_TRUE;
	}
#else
	MR_fatal_error(""minimal model code entered when not enabled"");
#endif
").

:- pragma foreign_proc("C",
	table_subgoal_status(Subgoal::in, Status::out),
	[will_not_call_mercury],
"
#ifdef MR_USE_MINIMAL_MODEL
	Status = MR_CONVERT_C_ENUM_CONSTANT(Subgoal->MR_sg_status);
#else
	MR_fatal_error(""minimal model code entered when not enabled"");
#endif
").

:- pragma promise_semipure(table_nondet_is_complete/1).
table_nondet_is_complete(_) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_nondet_is_complete").

:- pragma promise_semipure(table_nondet_is_active/1).
table_nondet_is_active(_) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_nondet_is_active").
	
table_nondet_mark_as_active(_) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_nondet_mark_as_active").

table_nondet_get_ans_table(_, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_nondet_get_ans_table").

table_nondet_answer_is_not_duplicate(_) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_nondet_answer_is_not_duplicate").

table_nondet_new_ans_slot(_, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_nondet_new_ans_slot").

:- pragma promise_semipure(pickup_answer_list/2).
pickup_answer_list(_, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("pickup_answer_list").

:- pragma promise_semipure(return_next_answer/3).
return_next_answer(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("return_next_answer").

:- pragma promise_semipure(table_subgoal_status/2).
table_subgoal_status(_, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_subgoal_status").

%-----------------------------------------------------------------------------%

:- interface.

%
% Utility predicates that are needed in the tabling of both
% simple and nondet subgoals.
%

%
% The following table_lookup_insert... predicates lookup or insert the second
% argument into the trie pointed to by the first argument. The value returned
% is a pointer to the leaf of the trie reached by the lookup. From the
% returned leaf another trie may be connected.
%

	% Lookup or insert an integer in the given table.
:- impure pred table_lookup_insert_int(ml_trie_node::in, int::in,
	ml_trie_node::out) is det.

	% Lookup or insert an integer in the given table.
:- impure pred table_lookup_insert_start_int(ml_trie_node::in, int::in,
	int::in, ml_trie_node::out) is det.

	% Lookup or insert a character in the given trie.
:- impure pred table_lookup_insert_char(ml_trie_node::in, character::in,
	ml_trie_node::out) is det.

	% Lookup or insert a string in the given trie.
:- impure pred table_lookup_insert_string(ml_trie_node::in, string::in,
	ml_trie_node::out) is det.

	% Lookup or insert a float in the current trie.
:- impure pred table_lookup_insert_float(ml_trie_node::in, float::in,
	ml_trie_node::out) is det.

	% Lookup or inert an enumeration type in the given trie.
:- impure pred table_lookup_insert_enum(ml_trie_node::in, int::in, T::in,
	ml_trie_node::out) is det.

	% Lookup or insert a monomorphic user defined type in the given trie.
:- impure pred table_lookup_insert_user(ml_trie_node::in, T::in,
	ml_trie_node::out) is det.

	% Lookup or insert a polymorphic user defined type in the given trie.
:- impure pred table_lookup_insert_poly(ml_trie_node::in, T::in,
	ml_trie_node::out) is det.

	% Save an integer answer in the given answer block at the given
	% offset.
:- impure pred table_save_int_ans(ml_answer_block::in, int::in, int::in)
	is det.

	% Save a character answer in the given answer block at the given
	% offset.
:- impure pred table_save_char_ans(ml_answer_block::in, int::in, character::in)
	is det.

	% Save a string answer in the given answer block at the given
	% offset.
:- impure pred table_save_string_ans(ml_answer_block::in, int::in, string::in)
	is det.

	% Save a float answer in the given answer block at the given
	% offset.
:- impure pred table_save_float_ans(ml_answer_block::in, int::in, float::in)
	is det.

	% Save an I/O state in the given answer block at the given offset.
:- impure pred table_save_io_state_ans(ml_answer_block::in, int::in,
	io__state::ui) is det.

	% Save any type of answer in the given answer block at the given
	% offset.
:- impure pred table_save_any_ans(ml_answer_block::in, int::in, T::in) is det.

	% Restore an integer answer from the given answer block at the
	% given offset.
:- semipure pred table_restore_int_ans(ml_answer_block::in, int::in, int::out)
	is det.

	% Restore a character answer from the given answer block at the
	% given offset.
:- semipure pred table_restore_char_ans(ml_answer_block::in, int::in,
	character::out) is det.

	% Restore a string answer from the given answer block at the
	% given offset.
:- semipure pred table_restore_string_ans(ml_answer_block::in, int::in,
	string::out) is det.

	% Restore a float answer from the given answer block at the
	% given offset.
:- semipure pred table_restore_float_ans(ml_answer_block::in, int::in,
	float::out) is det.

	% Restore an I/O state from the given answer block at the given offset.
:- semipure pred table_restore_io_state_ans(ml_answer_block::in, int::in,
	io__state::uo) is det.

	% Restore any type of answer from the given answer block at the
	% given offset.
:- semipure pred table_restore_any_ans(ml_answer_block::in, int::in, T::out)
	is det.

	% Report an error message about the current subgoal looping.
:- pred table_loopcheck_error(string::in) is erroneous.

	% Create an answer block with the given number of slots and add it
	% to the given table.
:- impure pred table_create_ans_block(ml_trie_node::in, int::in,
	ml_answer_block::out) is det.

	% Report statistics on the operation of the tabling system to stderr.
:- impure pred table_report_statistics is det.

%-----------------------------------------------------------------------------%

:- implementation.
:- import_module require.

:- pragma foreign_decl("C", "

#include ""mercury_misc.h""		/* for MR_fatal_error(); */
#include ""mercury_type_info.h""	/* for MR_TypeCtorInfo_Struct; */
#include ""mercury_tabling.h""		/* for MR_TrieNode, etc. */

MR_DECLARE_TYPE_CTOR_INFO_STRUCT(MR_TYPE_CTOR_INFO_NAME(io, state, 0));

").

:- pragma foreign_proc("C",
	table_lookup_insert_int(T0::in, I::in, T::out),
	[will_not_call_mercury],
"
	MR_DEBUG_NEW_TABLE_INT(T, T0, (MR_Integer) I);
").

:- pragma foreign_proc("C",
	table_lookup_insert_start_int(T0::in, S::in, I::in, T::out),
	[will_not_call_mercury],
"
	MR_DEBUG_NEW_TABLE_START_INT(T, T0, (MR_Integer) S, (MR_Integer) I);
").

:- pragma foreign_proc("C",
	table_lookup_insert_char(T0::in, C::in, T::out),
	[will_not_call_mercury],
"
	MR_DEBUG_NEW_TABLE_CHAR(T, T0, (MR_Integer) C);
").

:- pragma foreign_proc("C",
	table_lookup_insert_string(T0::in, S::in, T::out),
	[will_not_call_mercury],
"
	MR_DEBUG_NEW_TABLE_STRING(T, T0, (MR_String) S);
").

:- pragma foreign_proc("C",
	table_lookup_insert_float(T0::in, F::in, T::out),
	[will_not_call_mercury],
"
	MR_DEBUG_NEW_TABLE_FLOAT(T, T0, F);
").

:- pragma foreign_proc("C", 
	table_lookup_insert_enum(T0::in, R::in, V::in, T::out),
	[will_not_call_mercury],
"
	MR_DEBUG_NEW_TABLE_ENUM(T, T0, R, V);
").

:- pragma foreign_proc("C",
	table_lookup_insert_user(T0::in, V::in, T::out),
	[will_not_call_mercury],
"
	MR_DEBUG_NEW_TABLE_ANY(T, T0, (MR_TypeInfo) TypeInfo_for_T, V);
").

:- pragma foreign_proc("C",
	table_lookup_insert_poly(T0::in, V::in, T::out),
	[will_not_call_mercury],
"
	MR_DEBUG_NEW_TABLE_ANY(T, T0, (MR_TypeInfo) TypeInfo_for_T, V);
").

:- pragma foreign_proc("C",
	table_save_int_ans(AB::in, Offset::in, I::in),
	[will_not_call_mercury],
"
	MR_TABLE_SAVE_ANSWER(AB, Offset, I,
		&MR_TYPE_CTOR_INFO_NAME(builtin, int, 0));
").

:- pragma foreign_proc("C",
	table_save_char_ans(AB::in, Offset::in, C::in),
	[will_not_call_mercury],
"
	MR_TABLE_SAVE_ANSWER(AB, Offset, C,
		&MR_TYPE_CTOR_INFO_NAME(builtin, character, 0));
").

:- pragma foreign_proc("C",
	table_save_string_ans(AB::in, Offset::in, S::in),
	[will_not_call_mercury],
"
	MR_TABLE_SAVE_ANSWER(AB, Offset, (MR_Word) S,
		&MR_TYPE_CTOR_INFO_NAME(builtin, string, 0));
").

:- pragma foreign_proc("C",
	table_save_float_ans(AB::in, Offset::in, F::in),
	[will_not_call_mercury],
"
#ifdef MR_HIGHLEVEL_CODE
	MR_TABLE_SAVE_ANSWER(AB, Offset, (MR_Word) MR_box_float(F),
		&MR_TYPE_CTOR_INFO_NAME(builtin, float, 0));
#else
	MR_TABLE_SAVE_ANSWER(AB, Offset, MR_float_to_word(F),
		&MR_TYPE_CTOR_INFO_NAME(builtin, float, 0));
#endif
").

:- pragma foreign_proc("C",
	table_save_io_state_ans(AB::in, Offset::in, S::ui),
	[will_not_call_mercury],
"
	MR_TABLE_SAVE_ANSWER(AB, Offset, (MR_Word) S,
		&MR_TYPE_CTOR_INFO_NAME(io, state, 0));
").

:- pragma foreign_proc("C", 
	table_save_any_ans(AB::in, Offset::in, V::in),
	[will_not_call_mercury],
"
	MR_TABLE_SAVE_ANSWER(AB, Offset, V, TypeInfo_for_T);
").

:- pragma foreign_proc("C",
	table_restore_int_ans(AB::in, Offset::in, I::out),
	[will_not_call_mercury, promise_semipure],
"
	I = (MR_Integer) MR_TABLE_GET_ANSWER(AB, Offset);
").

:- pragma foreign_proc("C",
	table_restore_char_ans(AB::in, Offset::in, C::out),
	[will_not_call_mercury, promise_semipure],
"
	C = (MR_Char) MR_TABLE_GET_ANSWER(AB, Offset);
").

:- pragma foreign_proc("C",
	table_restore_string_ans(AB::in, Offset::in, S::out),
	[will_not_call_mercury, promise_semipure],
"
	S = (MR_String) MR_TABLE_GET_ANSWER(AB, Offset);
").

:- pragma foreign_proc("C",
	table_restore_float_ans(AB::in, Offset::in, F::out),
	[will_not_call_mercury, promise_semipure],
"
#ifdef MR_HIGHLEVEL_CODE
	F = MR_unbox_float(MR_TABLE_GET_ANSWER(AB, Offset));
#else
	F = MR_word_to_float(MR_TABLE_GET_ANSWER(AB, Offset));
#endif
").

:- pragma foreign_proc("C",
	table_restore_io_state_ans(AB::in, Offset::in, V::uo),
	[will_not_call_mercury, promise_semipure],
"
	V = (MR_Word) MR_TABLE_GET_ANSWER(AB, Offset);
").

:- pragma foreign_proc("C",
	table_restore_any_ans(AB::in, Offset::in, V::out),
	[will_not_call_mercury, promise_semipure],
"
	V = (MR_Word) MR_TABLE_GET_ANSWER(AB, Offset);
").

:- pragma foreign_proc("C",
	table_create_ans_block(T::in, Size::in, AB::out),
	[will_not_call_mercury],
"
	MR_TABLE_CREATE_ANSWER_BLOCK(T, Size);
	AB = T->MR_answerblock;
").

table_loopcheck_error(Message) :-
	error(Message).

:- pragma foreign_proc("C",
	table_report_statistics, [will_not_call_mercury], "
	MR_table_report_statistics(stderr);
").

table_lookup_insert_int(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_lookup_insert_int").

table_lookup_insert_start_int(_, _, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_lookup_insert_start_int").

table_lookup_insert_char(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_lookup_insert_char").

table_lookup_insert_string(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_lookup_insert_string").

table_lookup_insert_float(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_lookup_insert_float").

table_lookup_insert_enum(_, _, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_lookup_insert_enum").

table_lookup_insert_user(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_lookup_insert_user").

table_lookup_insert_poly(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_lookup_insert_poly").

table_save_int_ans(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_save_int_ans").

table_save_char_ans(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_save_char_ans").

table_save_string_ans(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_save_string_ans").

table_save_float_ans(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_save_float_ans").

table_save_io_state_ans(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_save_io_state_ans").

table_save_any_ans(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_save_any_ans").

:- pragma promise_semipure(table_restore_int_ans/3).
table_restore_int_ans(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_restore_int_ans").

:- pragma promise_semipure(table_restore_char_ans/3).
table_restore_char_ans(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_restore_char_ans").

:- pragma promise_semipure(table_restore_string_ans/3).
table_restore_string_ans(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_restore_string_ans").

:- pragma promise_semipure(table_restore_float_ans/3).
table_restore_float_ans(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_restore_float_ans").

:- pragma promise_semipure(table_restore_io_state_ans/3).
table_restore_io_state_ans(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_restore_io_state_ans").

:- pragma promise_semipure(table_restore_any_ans/3).
table_restore_any_ans(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_restore_any_ans").

table_create_ans_block(_, _, _) :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_create_ans_block").

table_report_statistics :-
	% This version is only used for back-ends for which there is no
	% matching foreign_proc version.
	impure private_builtin__imp,
	private_builtin__sorry("table_report_statistics").

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%
