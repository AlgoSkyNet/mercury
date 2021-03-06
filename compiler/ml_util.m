%-----------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sw=4 et
%-----------------------------------------------------------------------------%
% Copyright (C) 1999-2007,2009,2012 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%
%
% File: ml_util.m.
% Main author: fjh, trd.
%
% This module contains utility predicates for manipulating the MLDS.
%
%-----------------------------------------------------------------------------%

:- module ml_backend.ml_util.
:- interface.

:- import_module libs.
:- import_module libs.globals.          % for foreign_language
:- import_module hlds.
:- import_module hlds.hlds_data.
:- import_module hlds.hlds_module.
:- import_module ml_backend.mlds.

:- import_module bool.
:- import_module list.
:- import_module maybe.

%-----------------------------------------------------------------------------%

    % Succeeds iff the definitions contain the entry point to
    % the a main predicate.
    %
:- pred defns_contain_main(list(mlds_defn)::in) is semidet.

%-----------------------------------------------------------------------------%

    % True if the statement is a directly recursive tail call which can be
    % optimized into a jump back to the start of the function.
    %
:- pred can_optimize_tailcall(mlds_qualified_entity_name::in, mlds_stmt::in)
    is semidet.

    % True if the statement is a directly-recursive call.
    %
:- pred call_is_recursive(mlds_qualified_entity_name::in, mlds_stmt::in)
    is semidet.

%-----------------------------------------------------------------------------%
%
% Routines that deal with statements.
%

    % Nondeterministically generates sub-statements from statements.
    %
:- pred statement_contains_statement(statement::in, statement::out) is multi.

:- pred stmt_contains_statement(mlds_stmt::in, statement::out) is nondet.

    % Succeeds iff this statement contains a reference to the
    % specified variable.
    %
:- func statement_contains_var(statement, mlds_data) = bool.

:- pred has_foreign_languages(statement::in, list(foreign_language)::out)
    is det.

%-----------------------------------------------------------------------------%
%
% Routines that deal with definitions.
%

    % defn_contains_foreign_code(NativeTargetLang, Defn):
    %
    % Succeeds iff this definition contains outline_foreign_proc statements,
    % or inline_target_code statements in a target language other than the
    % specified native target language.
    %
    % XXX perhaps we should eliminate the need to check for inline_target_code,
    % because it shouldn't be generated with target language different to the
    % native target language in the long run.
    %
:- pred defn_contains_foreign_code(mlds_target_lang::in,
    mlds_defn::in) is semidet.

    % defn_contains_foreign_code(ForeignLang, Defn):
    %
    % Succeeds iff this definition contains outline_foreign_proc statements
    % for the given foreign language.
    %
:- pred defn_contains_outline_foreign_proc(foreign_language::in,
    mlds_defn::in) is semidet.

    % Succeeds iff this definition is a type definition.
    %
:- pred defn_is_type(mlds_defn::in) is semidet.

    % Succeeds iff this definition is a function definition.
    %
:- pred defn_is_function(mlds_defn::in) is semidet.

    % Succeeds iff this definition is a data definition which
    % defines a type_ctor_info constant.
    %
:- pred defn_is_type_ctor_info(mlds_defn::in) is semidet.

    % Succeeds iff this definition is a data definition which
    % defines a variable whose type is mlds_commit_type.
    %
:- pred defn_is_commit_type_var(mlds_defn::in) is semidet.

    % Succeeds iff this definition has `public' in the access
    % field in its decl_flags.
    %
:- pred defn_is_public(mlds_defn::in) is semidet.

    % Says whether these definitions contains a reference to
    % the specified variable.
    %
:- func defns_contains_var(list(mlds_defn), mlds_data) = bool.

    % Says whether this definition contains a reference to
    % the specified variable.
    %
:- func defn_contains_var(mlds_defn, mlds_data) = bool.

%-----------------------------------------------------------------------------%
%
% Routines that deal with lvals/rvals.
%

% initializer_contains_var:
% rvals_contains_var:
% maybe_rval_contains_var:
% rval_contains_var:
% lvals_contains_var:
% lval_contains_var:
%
% Succeed iff the specified construct contains a reference to
% the specified variable.

:- func initializer_contains_var(mlds_initializer, mlds_data) = bool.

:- func rvals_contains_var(list(mlds_rval), mlds_data) = bool.

:- func maybe_rval_contains_var(maybe(mlds_rval), mlds_data) = bool.

:- func rval_contains_var(mlds_rval, mlds_data) = bool.

:- func lvals_contains_var(list(mlds_lval), mlds_data) = bool.

:- func lval_contains_var(mlds_lval, mlds_data) = bool.

%-----------------------------------------------------------------------------%
%
% Functions for generating initializers.
%
% This handles arrays, maybe, null pointers, strings, ints, and builtin enums.

:- func gen_init_builtin_const(string) = mlds_initializer.

:- func gen_init_array(func(T) = mlds_initializer, list(T)) = mlds_initializer.

:- func gen_init_maybe(mlds_type, func(T) = mlds_initializer, maybe(T)) =
    mlds_initializer.

:- func gen_init_null_pointer(mlds_type) = mlds_initializer.

:- func gen_init_string(string) = mlds_initializer.

:- func gen_init_foreign(foreign_language, string) = mlds_initializer.

:- func gen_init_int(int) = mlds_initializer.

:- func gen_init_bool(bool) = mlds_initializer.

:- func gen_init_boxed_int(int) = mlds_initializer.

:- func gen_init_reserved_address(module_info, reserved_address) =
    mlds_initializer.

:- func wrap_init_obj(mlds_rval) = mlds_initializer.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module backend_libs.
:- import_module backend_libs.rtti.
:- import_module mdbcomp.
:- import_module mdbcomp.builtin_modules.
:- import_module mdbcomp.prim_data.
:- import_module ml_backend.ml_unify_gen.

:- import_module solutions.

%-----------------------------------------------------------------------------%

defns_contain_main([Defn | Defns]) :-
    (
        Defn = mlds_defn(Name, _, _, _),
        Name = entity_function(FuncName, _, _, _),
        FuncName = mlds_user_pred_label(pf_predicate, _, "main", 2, _, _)
    ;
        defns_contain_main(Defns)
    ).

can_optimize_tailcall(Name, Call) :-
    Call = ml_stmt_call(_Signature, _FuncRval, MaybeObject, _CallArgs,
        _Results, CallKind),
    % Check if this call can be optimized as a tail call.
    ( CallKind = tail_call ; CallKind = no_return_call ),

    % In C++, `this' is a constant, so our usual technique of assigning
    % the arguments won't work if it is a member function. Thus we don't do
    % this optimization if we're optimizing a member function call.
    MaybeObject = no,

    call_is_recursive(Name, Call).

call_is_recursive(Name, Call) :-
    Call = ml_stmt_call(_Signature, FuncRval, _MaybeObject, _CallArgs,
        _Results, _CallKind),

    % Check if the callee address is the same as the caller.
    FuncRval = ml_const(mlconst_code_addr(CodeAddr)),
    (
        CodeAddr = code_addr_proc(QualifiedProcLabel, _Sig),
        MaybeSeqNum = no
    ;
        CodeAddr = code_addr_internal(QualifiedProcLabel, SeqNum, _Sig),
        MaybeSeqNum = yes(SeqNum)
    ),
    ProcLabel = mlds_proc_label(PredLabel, ProcId),
    QualifiedProcLabel = qual(ModuleName, module_qual, ProcLabel),

    % Check that the module name matches.
    Name = qual(ModuleName, module_qual, FuncName),

    % Check that the PredLabel, ProcId, and MaybeSeqNum match.
    FuncName = entity_function(PredLabel, ProcId, MaybeSeqNum, _).

%-----------------------------------------------------------------------------%
%
% Routines that deal with statements.
%

% statement_contains_statement:
% statements_contains_statement:
% maybe_statement_contains_statement:
%
% Nondeterministically generate sub-statements from statements.

:- pred statements_contains_statement(list(statement)::in,
    statement::out) is nondet.

statements_contains_statement(Statements, SubStatement) :-
    list.member(Statement, Statements),
    statement_contains_statement(Statement, SubStatement).

:- pred maybe_statement_contains_statement(maybe(statement)::in,
    statement::out) is nondet.

maybe_statement_contains_statement(no, _Statement) :- fail.
maybe_statement_contains_statement(yes(Statement), SubStatement) :-
    statement_contains_statement(Statement, SubStatement).

statement_contains_statement(Statement, Statement).
statement_contains_statement(Statement, SubStatement) :-
    Statement = statement(Stmt, _Context),
    stmt_contains_statement(Stmt, SubStatement).

stmt_contains_statement(Stmt, SubStatement) :-
    (
        Stmt = ml_stmt_block(_Defns, Statements),
        statements_contains_statement(Statements, SubStatement)
    ;
        Stmt = ml_stmt_while(_Kind, _Rval, Statement),
        statement_contains_statement(Statement, SubStatement)
    ;
        Stmt = ml_stmt_if_then_else(_Cond, Then, MaybeElse),
        ( statement_contains_statement(Then, SubStatement)
        ; maybe_statement_contains_statement(MaybeElse, SubStatement)
        )
    ;
        Stmt = ml_stmt_switch(_Type, _Val, _Range, Cases, Default),
        ( cases_contains_statement(Cases, SubStatement)
        ; default_contains_statement(Default, SubStatement)
        )
    ;
        Stmt = ml_stmt_try_commit(_Ref, Statement, Handler),
        ( statement_contains_statement(Statement, SubStatement)
        ; statement_contains_statement(Handler, SubStatement)
        )
    ;
        ( Stmt = ml_stmt_label(_Label)
        ; Stmt = ml_stmt_goto(_)
        ; Stmt = ml_stmt_computed_goto(_Rval, _Labels)
        ; Stmt = ml_stmt_call(_Sig, _Func, _Obj, _Args, _RetLvals, _TailCall)
        ; Stmt = ml_stmt_return(_Rvals)
        ; Stmt = ml_stmt_do_commit(_Ref)
        ; Stmt = ml_stmt_atomic(_AtomicStmt)
        ),
        fail
    ).

:- pred cases_contains_statement(list(mlds_switch_case)::in,
    statement::out) is nondet.

cases_contains_statement(Cases, SubStatement) :-
    list.member(Case, Cases),
    Case = mlds_switch_case(_FirstCond, _LaterConds, Statement),
    statement_contains_statement(Statement, SubStatement).

:- pred default_contains_statement(mlds_switch_default::in,
    statement::out) is nondet.

default_contains_statement(default_do_nothing, _) :- fail.
default_contains_statement(default_is_unreachable, _) :- fail.
default_contains_statement(default_case(Statement), SubStatement) :-
    statement_contains_statement(Statement, SubStatement).

%-----------------------------------------------------------------------------%
%
% statements_contains_var:
% maybe_statement_contains_var:
% statement_contains_var:
% trail_op_contains_var:
% atomic_stmt_contains_var:
%
% Succeed iff the specified construct contains a reference to
% the specified variable.

:- func statements_contains_var(list(statement), mlds_data) = bool.

statements_contains_var([], _DataName) = no.
statements_contains_var([Statement | Statements], DataName) = ContainsVar :-
    StatementContainsVar = statement_contains_var(Statement, DataName),
    (
        StatementContainsVar = yes,
        ContainsVar = yes
    ;
        StatementContainsVar = no,
        ContainsVar = statements_contains_var(Statements, DataName)
    ).

:- func maybe_statement_contains_var(maybe(statement), mlds_data) = bool.

maybe_statement_contains_var(no, _) = no.
maybe_statement_contains_var(yes(Statement), DataName) = ContainsVar :-
    ContainsVar = statement_contains_var(Statement, DataName).

statement_contains_var(Statement, DataName) = ContainsVar :-
    Statement = statement(Stmt, _Context),
    ContainsVar = stmt_contains_var(Stmt, DataName).

:- func stmt_contains_var(mlds_stmt, mlds_data) = bool.

stmt_contains_var(Stmt, DataName) = ContainsVar :-
    (
        Stmt = ml_stmt_block(Defns, Statements),
        DefnsContainVar = defns_contains_var(Defns, DataName),
        (
            DefnsContainVar = yes,
            ContainsVar = yes
        ;
            DefnsContainVar = no,
            ContainsVar = statements_contains_var(Statements, DataName)
        )
    ;
        Stmt = ml_stmt_while(_Kind, Rval, Statement),
        RvalContainsVar = rval_contains_var(Rval, DataName),
        (
            RvalContainsVar = yes,
            ContainsVar = yes
        ;
            RvalContainsVar = no,
            ContainsVar = statement_contains_var(Statement, DataName)
        )
    ;
        Stmt = ml_stmt_if_then_else(Cond, Then, MaybeElse),
        CondContainsVar = rval_contains_var(Cond, DataName),
        (
            CondContainsVar = yes,
            ContainsVar = yes
        ;
            CondContainsVar = no,
            ThenContainsVar = statement_contains_var(Then, DataName),
            (
                ThenContainsVar = yes,
                ContainsVar = yes
            ;
                ThenContainsVar = no,
                ContainsVar = maybe_statement_contains_var(MaybeElse, DataName)
            )
        )
    ;
        Stmt = ml_stmt_switch(_Type, Val, _Range, Cases, Default),
        ValContainsVar = rval_contains_var(Val, DataName),
        (
            ValContainsVar = yes,
            ContainsVar = yes
        ;
            ValContainsVar = no,
            CasesContainsVar = cases_contains_var(Cases, DataName),
            (
                CasesContainsVar = yes,
                ContainsVar = yes
            ;
                CasesContainsVar = no,
                ContainsVar = default_contains_var(Default, DataName)
            )
        )
    ;
        ( Stmt = ml_stmt_label(_Label)
        ; Stmt = ml_stmt_goto(_)
        ),
        ContainsVar = no
    ;
        Stmt = ml_stmt_computed_goto(Rval, _Labels),
        ContainsVar = rval_contains_var(Rval, DataName)
    ;
        Stmt = ml_stmt_call(_Sig, Func, Obj, Args, RetLvals, _TailCall),
        FuncContainsVar = rval_contains_var(Func, DataName),
        (
            FuncContainsVar = yes,
            ContainsVar = yes
        ;
            FuncContainsVar = no,
            ObjContainsVar = maybe_rval_contains_var(Obj, DataName),
            (
                ObjContainsVar = yes,
                ContainsVar = yes
            ;
                ObjContainsVar = no,
                ArgsContainVar = rvals_contains_var(Args, DataName),
                (
                    ArgsContainVar = yes,
                    ContainsVar = yes
                ;
                    ArgsContainVar = no,
                    ContainsVar = lvals_contains_var(RetLvals, DataName)
                )
            )
        )
    ;
        Stmt = ml_stmt_return(Rvals),
        ContainsVar = rvals_contains_var(Rvals, DataName)
    ;
        Stmt = ml_stmt_do_commit(Ref),
        ContainsVar = rval_contains_var(Ref, DataName)
    ;
        Stmt = ml_stmt_try_commit(Ref, Statement, Handler),
        RefContainsVar = lval_contains_var(Ref, DataName),
        (
            RefContainsVar = yes,
            ContainsVar = yes
        ;
            RefContainsVar = no,
            StatementContainsVar = statement_contains_var(Statement, DataName),
            (
                StatementContainsVar = yes,
                ContainsVar = yes
            ;
                StatementContainsVar = no,
                ContainsVar = statement_contains_var(Handler, DataName)
            )
        )
    ;
        Stmt = ml_stmt_atomic(AtomicStmt),
        ContainsVar = atomic_stmt_contains_var(AtomicStmt, DataName)
    ).

:- func cases_contains_var(list(mlds_switch_case), mlds_data) = bool.

cases_contains_var([], _DataName) = no.
cases_contains_var([Case | Cases], DataName) = ContainsVar :-
    Case = mlds_switch_case(_FirstCond, _LaterConds, Statement),
    StatementContainsVar = statement_contains_var(Statement, DataName),
    (
        StatementContainsVar = yes,
        ContainsVar = yes
    ;
        StatementContainsVar = no,
        ContainsVar = cases_contains_var(Cases, DataName)
    ).

:- func default_contains_var(mlds_switch_default, mlds_data) = bool.

default_contains_var(Default, DataName) = ContainsVar :-
    (
        ( Default = default_do_nothing
        ; Default = default_is_unreachable
        ),
        ContainsVar = no
    ;
        Default = default_case(Statement),
        ContainsVar = statement_contains_var(Statement, DataName)
    ).

:- func atomic_stmt_contains_var(mlds_atomic_statement, mlds_data) = bool.

atomic_stmt_contains_var(AtomicStmt, DataName) = ContainsVar :-
    (
        AtomicStmt = comment(_),
        ContainsVar = no
    ;
        ( AtomicStmt = assign(Lval, Rval)
        ; AtomicStmt = assign_if_in_heap(Lval, Rval)
        ),
        LvalContainsVar = lval_contains_var(Lval, DataName),
        (
            LvalContainsVar = yes,
            ContainsVar = yes
        ;
            LvalContainsVar = no,
            ContainsVar = rval_contains_var(Rval, DataName)
        )
    ;
        AtomicStmt = delete_object(Rval),
        ContainsVar = rval_contains_var(Rval, DataName)
    ;
        AtomicStmt = new_object(Target, _MaybeTag, _ExplicitSecTag, _Type,
            _MaybeSize, _MaybeCtorName, Args, _ArgTypes, _MayUseAtomic,
            _AllocId),
        TargetContainsVar = lval_contains_var(Target, DataName),
        (
            TargetContainsVar = yes,
            ContainsVar = yes
        ;
            TargetContainsVar = no,
            ContainsVar = rvals_contains_var(Args, DataName)
        )
    ;
        AtomicStmt = gc_check,
        ContainsVar = no
    ;
        AtomicStmt = mark_hp(Lval),
        ContainsVar = lval_contains_var(Lval, DataName)
    ;
        AtomicStmt = restore_hp(Rval),
        ContainsVar = rval_contains_var(Rval, DataName)
    ;
        AtomicStmt = trail_op(TrailOp),
        ContainsVar = trail_op_contains_var(TrailOp, DataName)
    ;
        AtomicStmt = inline_target_code(_Lang, Components),
        ContainsVar = target_code_components_contains_var(Components, DataName)
    ;
        AtomicStmt = outline_foreign_proc(_Lang, OutlineArgs, ReturnLvals,
            _Code),
        OutlineArgsContainVar =
            outline_args_contains_var(OutlineArgs, DataName),
        (
            OutlineArgsContainVar = yes,
            ContainsVar = yes
        ;
            OutlineArgsContainVar = no,
            ContainsVar = lvals_contains_var(ReturnLvals, DataName)
        )
    ).

:- func trail_op_contains_var(trail_op, mlds_data) = bool.

trail_op_contains_var(TrailOp, DataName) = ContainsVar :-
    (
        TrailOp = store_ticket(Lval),
        ContainsVar = lval_contains_var(Lval, DataName)
    ;
        TrailOp = reset_ticket(Rval, _Reason),
        ContainsVar = rval_contains_var(Rval, DataName)
    ;
        ( TrailOp = discard_ticket
        ; TrailOp = prune_ticket
        ),
        ContainsVar = no
    ;
        TrailOp = mark_ticket_stack(Lval),
        ContainsVar = lval_contains_var(Lval, DataName)
    ;
        TrailOp = prune_tickets_to(Rval),
        ContainsVar = rval_contains_var(Rval, DataName)
    ).

:- func target_code_components_contains_var(list(target_code_component),
    mlds_data) = bool.

target_code_components_contains_var([], _DataName) = no.
target_code_components_contains_var([TargetCode | TargetCodes], DataName)
        = ContainsVar :-
    TargetCodeContainsVar =
        target_code_component_contains_var(TargetCode, DataName),
    (
        TargetCodeContainsVar = yes,
        ContainsVar = yes
    ;
        TargetCodeContainsVar = no,
        ContainsVar =
            target_code_components_contains_var(TargetCodes, DataName)
    ).

:- func target_code_component_contains_var(target_code_component, mlds_data)
    = bool.

target_code_component_contains_var(TargetCode, DataName) = ContainsVar :-
    (
        ( TargetCode = user_target_code(_, _)
        ; TargetCode = raw_target_code(_)
        ; TargetCode = target_code_type(_)
        ; TargetCode = target_code_alloc_id(_)
        ),
        ContainsVar = no
    ;
        TargetCode = target_code_input(Rval),
        ContainsVar = rval_contains_var(Rval, DataName)
    ;
        TargetCode = target_code_output(Lval),
        ContainsVar = lval_contains_var(Lval, DataName)
    ;
        TargetCode = target_code_name(EntityName),
        ( if
            EntityName = qual(ModuleName, QualKind,
                entity_data(UnqualDataName)),
            DataName = qual(ModuleName, QualKind, UnqualDataName)
        then
            ContainsVar = yes
        else
            ContainsVar = no
        )
    ).

:- func outline_args_contains_var(list(outline_arg), mlds_data) = bool.

outline_args_contains_var([], _DataName) = no.
outline_args_contains_var([OutlineArg | OutlineArgs], DataName) =
        ContainsVar :-
    OutlineArgContainsVar = outline_arg_contains_var(OutlineArg, DataName),
    (
        OutlineArgContainsVar = yes,
        ContainsVar = yes
    ;
        OutlineArgContainsVar = no,
        ContainsVar = outline_args_contains_var(OutlineArgs, DataName)
    ).

:- func outline_arg_contains_var(outline_arg, mlds_data) = bool.

outline_arg_contains_var(OutlineArg, DataName) = ContainsVar :-
    (
        OutlineArg = ola_in(_Type, _Str, Rval),
        ContainsVar = rval_contains_var(Rval, DataName)
    ;
        OutlineArg = ola_out(_Type, _Str, Lval),
        ContainsVar = lval_contains_var(Lval, DataName)
    ;
        OutlineArg = ola_unused,
        ContainsVar = no
    ).

%-----------------------------------------------------------------------------%

has_foreign_languages(Statement, Langs) :-
    GetTargetCode = (pred(Lang::out) is nondet :-
        statement_contains_statement(Statement, SubStatement),
        SubStatement = statement(ml_stmt_atomic(
            outline_foreign_proc(Lang, _, _, _)), _)
        ),
    solutions.solutions(GetTargetCode, Langs).

%-----------------------------------------------------------------------------%
%
% Routines that deal with definitions.
%

defn_contains_foreign_code(NativeTargetLang, Defn) :-
    Defn = mlds_defn(_Name, _Context, _Flags, Body),
    Body = mlds_function(_, _, body_defined_here(FunctionBody), _, _, _),
    statement_contains_statement(FunctionBody, Statement),
    Statement = statement(Stmt, _),
    (
        Stmt = ml_stmt_atomic(inline_target_code(TargetLang, _)),
        TargetLang \= NativeTargetLang
    ;
        Stmt = ml_stmt_atomic(outline_foreign_proc(_, _, _, _))
    ).

defn_contains_outline_foreign_proc(ForeignLang, Defn) :-
    Defn = mlds_defn(_Name, _Context, _Flags, Body),
    Body = mlds_function(_, _, body_defined_here(FunctionBody), _, _, _),
    statement_contains_statement(FunctionBody, Statement),
    Statement = statement(Stmt, _),
    Stmt = ml_stmt_atomic(outline_foreign_proc(ForeignLang, _, _, _)).

defn_is_type(Defn) :-
    Defn = mlds_defn(Name, _Context, _Flags, _Body),
    Name = entity_type(_, _).

defn_is_function(Defn) :-
    Defn = mlds_defn(Name, _Context, _Flags, _Body),
    Name = entity_function(_, _, _, _).

defn_is_type_ctor_info(Defn) :-
    Defn = mlds_defn(_Name, _Context, _Flags, Body),
    Body = mlds_data(Type, _, _),
    Type = mlds_rtti_type(item_type(RttiId)),
    RttiId = ctor_rtti_id(_, RttiName),
    RttiName = type_ctor_type_ctor_info.

defn_is_commit_type_var(Defn) :-
    Defn = mlds_defn(_Name, _Context, _Flags, Body),
    Body = mlds_data(Type, _, _),
    Type = mlds_commit_type.

defn_is_public(Defn) :-
    Defn = mlds_defn(_Name, _Context, Flags, _Body),
    access(Flags) = acc_public.

%-----------------------------------------------------------------------------%
%
% defns_contains_var:
% defn_contains_var:
% defn_body_contains_var:
% function_body_contains_var:
%
% Succeed iff the specified construct contains a reference to
% the specified variable.

defns_contains_var([], _DataName) = no.
defns_contains_var([Defn | Defns], DataName) = ContainsVar :-
    DefnContainsVar = defn_contains_var(Defn, DataName),
    (
        DefnContainsVar = yes,
        ContainsVar = yes
    ;
        DefnContainsVar = no,
        ContainsVar = defns_contains_var(Defns, DataName)
    ).

defn_contains_var(Defn, DataName) = ContainsVar :-
    Defn = mlds_defn(_Name, _Context, _Flags, DefnBody),
    ContainsVar = defn_body_contains_var(DefnBody, DataName).

:- func defn_body_contains_var(mlds_entity_defn, mlds_data) = bool.

defn_body_contains_var(DefnBody, DataName) = ContainsVar :-
    (
        DefnBody = mlds_data(_Type, Initializer, _GCStatement),
        % XXX Should we include variables in the GCStatement field here?
        ContainsVar = initializer_contains_var(Initializer, DataName)
    ;
        DefnBody = mlds_function(_PredProcId, _Params, FunctionBody,
            _Attrs, _EnvVarNames, _MaybeRequireTailrecInfo),
        ContainsVar = function_body_contains_var(FunctionBody, DataName)
    ;
        DefnBody = mlds_class(ClassDefn),
        ClassDefn = mlds_class_defn(_Kind, _Imports, _Inherits, _Implements,
            _TypeParams, CtorDefns, FieldDefns),
        FieldDefnsContainVar = defns_contains_var(FieldDefns, DataName),
        (
            FieldDefnsContainVar = yes,
            ContainsVar = yes
        ;
            FieldDefnsContainVar = no,
            ContainsVar = defns_contains_var(CtorDefns, DataName)
        )
    ).

:- func function_body_contains_var(mlds_function_body, mlds_data) = bool.

function_body_contains_var(Body, DataName) = ContainsVar :-
    (
        Body = body_external,
        ContainsVar = no
    ;
        Body = body_defined_here(Statement),
        ContainsVar = statement_contains_var(Statement, DataName)
    ).

%-----------------------------------------------------------------------------%
%
% Routines that deal with lvals/rvals.
%

% initializer_contains_var:
% initializers_contains_var:
% rvals_contains_var:
% maybe_rval_contains_var:
% rval_contains_var:
% lvals_contains_var:
% lval_contains_var:
%
% Say whether the specified construct contains a reference to
% the specified variable.

initializer_contains_var(Initializer, DataName) = ContainsVar :-
    (
        Initializer = no_initializer,
        ContainsVar = no
    ;
        Initializer = init_obj(Rval),
        ContainsVar = rval_contains_var(Rval, DataName)
    ;
        Initializer = init_struct(_Type, FieldInitializers),
        ContainsVar = initializers_contains_var(FieldInitializers, DataName)
    ;
        Initializer = init_array(ElementInitializers),
        ContainsVar = initializers_contains_var(ElementInitializers, DataName)
    ).

:- func initializers_contains_var(list(mlds_initializer), mlds_data) = bool.

initializers_contains_var([], _DataName) = no.
initializers_contains_var([Initializer | Initializers], DataName) =
        ContainsVar :-
    InitializerContainsVar = initializer_contains_var(Initializer, DataName),
    (
        InitializerContainsVar = yes,
        ContainsVar = yes
    ;
        InitializerContainsVar = no,
        ContainsVar = initializers_contains_var(Initializers, DataName)
    ).

rvals_contains_var([], _DataName) = no.
rvals_contains_var([Rval | Rvals], DataName) = ContainsVar :-
    RvalContainsVar = rval_contains_var(Rval, DataName),
    (
        RvalContainsVar = yes,
        ContainsVar = yes
    ;
        RvalContainsVar = no,
        ContainsVar = rvals_contains_var(Rvals, DataName)
    ).

maybe_rval_contains_var(no, _DataName) = no.
maybe_rval_contains_var(yes(Rval), DataName) =
    rval_contains_var(Rval, DataName).

rval_contains_var(Rval, DataName) = ContainsVar :-
    (
        Rval = ml_lval(Lval),
        ContainsVar = lval_contains_var(Lval, DataName)
    ;
        Rval = ml_mkword(_Tag, SubRval),
        ContainsVar = rval_contains_var(SubRval, DataName)
    ;
        Rval = ml_const(Const),
        (
            Const = mlconst_data_addr(DataAddr),
            DataAddr = data_addr(ModuleName, RawDataName),
            ( if DataName = qual(ModuleName, _QualKind, RawDataName) then
                % This is a place where we can succeed.
                ContainsVar = yes
            else
                ContainsVar = no
            )
        ;
            ( Const = mlconst_true
            ; Const = mlconst_false
            ; Const = mlconst_int(_)
            ; Const = mlconst_uint(_)
            ; Const = mlconst_enum(_, _)
            ; Const = mlconst_char(_)
            ; Const = mlconst_float(_)
            ; Const = mlconst_string(_)
            ; Const = mlconst_multi_string(_)
            ; Const = mlconst_foreign(_, _, _)
            ; Const = mlconst_named_const(_)
            ; Const = mlconst_code_addr(_)
            ; Const = mlconst_null(_)
            ),
            ContainsVar = no
        )
    ;
        Rval = ml_unop(_Op, RvalA),
        ContainsVar = rval_contains_var(RvalA, DataName)
    ;
        Rval = ml_binop(_Op, RvalA, RvalB),
        RvalAContainsVar = rval_contains_var(RvalA, DataName),
        (
            RvalAContainsVar = yes,
            ContainsVar = yes
        ;
            RvalAContainsVar = no,
            ContainsVar = rval_contains_var(RvalB, DataName)
        )
    ;
        Rval = ml_mem_addr(Lval),
        ContainsVar = lval_contains_var(Lval, DataName)
    ;
        Rval = ml_scalar_common(_ScalarCommon),
        ContainsVar = no
    ;
        Rval = ml_vector_common_row(_VectorCommon, IndexRval),
        ContainsVar = rval_contains_var(IndexRval, DataName)
    ;
        Rval = ml_self(_),
        ContainsVar = no
    ).

lvals_contains_var([], _DataName) = no.
lvals_contains_var([Lval | Lvals], DataName) = ContainsVar :-
    LvalContainsVar = lval_contains_var(Lval, DataName),
    (
        LvalContainsVar = yes,
        ContainsVar = yes
    ;
        LvalContainsVar = no,
        ContainsVar = lvals_contains_var(Lvals, DataName)
    ).

lval_contains_var(Lval, DataName) = ContainsVar :-
    (
        Lval = ml_field(_MaybeTag, Rval, _FieldId, _, _),
        ContainsVar = rval_contains_var(Rval, DataName)
    ;
        Lval = ml_mem_ref(Rval, _Type),
        ContainsVar = rval_contains_var(Rval, DataName)
    ;
        Lval = ml_global_var_ref(_),
        ContainsVar = no
    ;
        Lval = ml_var(qual(ModuleName, QualKind, Name), _Type),
        % This is another place where we can succeed.
        ( if DataName = qual(ModuleName, QualKind, mlds_data_var(Name)) then
            ContainsVar = yes
        else
            ContainsVar =no
        )
    ).

%-----------------------------------------------------------------------------%

gen_init_builtin_const(Name) = init_obj(Rval) :-
    PrivateBuiltin = mercury_private_builtin_module,
    MLDS_Module = mercury_module_name_to_mlds(PrivateBuiltin),
    % XXX These are actually enumeration constants.
    % Perhaps we should be using an enumeration type here,
    % rather than `mlds_native_int_type'.
    Type = mlds_native_int_type,
    Rval = ml_lval(ml_var(qual(MLDS_Module, module_qual,
        mlds_var_name(Name, no)), Type)).

gen_init_array(Conv, List) = init_array(list.map(Conv, List)).

gen_init_maybe(_Type, Conv, yes(X)) = Conv(X).
gen_init_maybe(Type, _Conv, no) = gen_init_null_pointer(Type).

gen_init_null_pointer(Type) = init_obj(ml_const(mlconst_null(Type))).

gen_init_string(String) = init_obj(ml_const(mlconst_string(String))).

gen_init_int(Int) = init_obj(ml_const(mlconst_int(Int))).

gen_init_foreign(Lang, String) =
    init_obj(ml_const(mlconst_foreign(Lang, String, mlds_native_int_type))).

gen_init_bool(no) = init_obj(ml_const(mlconst_false)).
gen_init_bool(yes) = init_obj(ml_const(mlconst_true)).

gen_init_boxed_int(Int) =
    init_obj(ml_unop(box(mlds_native_int_type), ml_const(mlconst_int(Int)))).

gen_init_reserved_address(ModuleInfo, ReservedAddress) =
    % XXX using `mlds_generic_type' here is probably wrong
    init_obj(ml_gen_reserved_address(ModuleInfo, ReservedAddress,
        mlds_generic_type)).

wrap_init_obj(Rval) = init_obj(Rval).

%-----------------------------------------------------------------------------%
:- end_module ml_backend.ml_util.
%-----------------------------------------------------------------------------%
