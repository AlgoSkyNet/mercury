%-----------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sw=4 et
%-----------------------------------------------------------------------------%
% Copyright (C) 2001-2002, 2004-2007 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%
% 
% File: startup.m.
% Authors: conway, zs.
%
% This module contains the code for turning the raw list of nodes read in by
% read_profile.m into the data structure that mdprof_cgi.m needs to service
% requests for web pages. The algorithm it implements is documented in the
% deep profiling paper.
%
%-----------------------------------------------------------------------------%

:- module startup.
:- interface.

:- import_module profile.

:- import_module bool.
:- import_module io.
:- import_module list.
:- import_module maybe.

%-----------------------------------------------------------------------------%

:- pred read_and_startup(string::in, string::in, list(string)::in,
    bool::in, maybe(io.output_stream)::in, list(string)::in, list(string)::in,
    maybe_error(deep)::out, io::di, io::uo) is det.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module array_util.
:- import_module callgraph.
:- import_module canonical.
:- import_module dump.
:- import_module measurements.
:- import_module profile.
:- import_module read_profile.

:- import_module array.
:- import_module int.
:- import_module map.
:- import_module require.
:- import_module string.
:- import_module svarray.
:- import_module svmap.

%-----------------------------------------------------------------------------%

read_and_startup(Machine, ScriptName, DataFileNames, Canonical,
        MaybeOutputStream, DumpStages, DumpOptions, Res, !IO) :-
    (
        DataFileNames = [],
        % This should have been caught and reported by main.
        error("read_and_startup: no data files")
    ;
        DataFileNames = [DataFileName],
        maybe_report_stats(MaybeOutputStream, !IO),
        maybe_report_msg(MaybeOutputStream,
            "% Reading graph data...\n", !IO),
        read_call_graph(DataFileName, Res0, !IO),
        maybe_report_msg(MaybeOutputStream,
            "% Done.\n", !IO),
        maybe_report_stats(MaybeOutputStream, !IO),
        (
            Res0 = ok(InitDeep),
            startup(Machine, ScriptName, DataFileName, Canonical,
                MaybeOutputStream, DumpStages, DumpOptions, InitDeep, Deep,
                !IO),
            Res = ok(Deep)
        ;
            Res0 = error(Error),
            Res = error(Error)
        )
    ;
        DataFileNames = [_, _ | _],
        error("mdprof_server: merging of data files is not yet implemented")
    ).

:- pred startup(string::in, string::in, string::in, bool::in,
    maybe(io.output_stream)::in, list(string)::in, list(string)::in,
    initial_deep::in, deep::out, io::di, io::uo) is det.

startup(Machine, ScriptName, DataFileName, Canonical, MaybeOutputStream,
        DumpStages, DumpOptions, InitDeep0, Deep, !IO) :-
    InitDeep0 = initial_deep(InitStats, Root,
        CallSiteDynamics0, ProcDynamics, CallSiteStatics0, ProcStatics0),
    maybe_dump(DataFileName, DumpStages, 0,
        dump_initial_deep(InitDeep0, DumpOptions), !IO),

    maybe_report_msg(MaybeOutputStream,
        "% Mapping static call sites to containing procedures...\n", !IO),
    array_foldl2_from_1(record_css_containers_module_procs, ProcStatics0,
        u(CallSiteStatics0), CallSiteStatics, map.init, ModuleProcs),
    maybe_report_msg(MaybeOutputStream,
        "% Done.\n", !IO),
    maybe_report_stats(MaybeOutputStream, !IO),

    maybe_report_msg(MaybeOutputStream,
        "% Mapping dynamic call sites to containing procedures...\n", !IO),
    array_foldl2_from_1(record_csd_containers_zeroed_pss, ProcDynamics,
        u(CallSiteDynamics0), CallSiteDynamics, u(ProcStatics0), ProcStatics),
    maybe_report_msg(MaybeOutputStream,
        "% Done.\n", !IO),
    maybe_report_stats(MaybeOutputStream, !IO),

    InitDeep1 = initial_deep(InitStats, Root,
        CallSiteDynamics, ProcDynamics, CallSiteStatics, ProcStatics),
    maybe_dump(DataFileName, DumpStages, 10,
        dump_initial_deep(InitDeep1, DumpOptions), !IO),
    (
        Canonical = no,
        InitDeep = InitDeep1
    ;
        Canonical = yes,
        maybe_report_msg(MaybeOutputStream,
            "% Canonicalizing cliques...\n", !IO),
        canonicalize_cliques(InitDeep1, InitDeep),
        maybe_report_msg(MaybeOutputStream,
            "% Done.\n", !IO),
        maybe_report_stats(MaybeOutputStream, !IO)
    ),
    maybe_dump(DataFileName, DumpStages, 20,
        dump_initial_deep(InitDeep, DumpOptions), !IO),

    array.max(InitDeep ^ init_proc_dynamics, PDMax),
    NPDs = PDMax + 1,
    array.max(InitDeep ^ init_call_site_dynamics, CSDMax),
    NCSDs = CSDMax + 1,
    array.max(InitDeep ^ init_proc_statics, PSMax),
    NPSs = PSMax + 1,
    array.max(InitDeep ^ init_call_site_statics, CSSMax),
    NCSSs = CSSMax + 1,

    maybe_report_msg(MaybeOutputStream,
        "% Finding cliques...\n", !IO),
    find_cliques(InitDeep, CliqueList),
    maybe_report_msg(MaybeOutputStream,
        "% Done.\n", !IO),
    maybe_report_stats(MaybeOutputStream, !IO),

    maybe_report_msg(MaybeOutputStream,
        "% Constructing clique indexes...\n", !IO),
    make_clique_indexes(NPDs, CliqueList, Cliques, CliqueIndex),
    maybe_report_msg(MaybeOutputStream,
        "% Done.\n", !IO),
    maybe_report_stats(MaybeOutputStream, !IO),

    maybe_report_msg(MaybeOutputStream,
        "% Constructing clique parent map...\n", !IO),

    % For each CallSiteDynamic pointer, if it points to a ProcDynamic
    % which is in a different clique to the one from which the
    % CallSiteDynamic's parent came, then this CallSiteDynamic is the entry to
    % the [lower] clique. We need to compute this information so that
    % we can print clique-based timing summaries in the browser.

    array.max(Cliques, CliqueMax),
    NCliques = CliqueMax + 1,
    array.init(NCliques, call_site_dynamic_ptr(-1), CliqueParents0),
    array.init(NCSDs, no, CliqueMaybeChildren0),
    array_foldl2_from_1(construct_clique_parents(InitDeep, CliqueIndex),
        CliqueIndex,
        CliqueParents0, CliqueParents,
        CliqueMaybeChildren0, CliqueMaybeChildren),

    maybe_report_msg(MaybeOutputStream,
        "% Done.\n", !IO),
    maybe_report_stats(MaybeOutputStream, !IO),

    maybe_report_msg(MaybeOutputStream,
        "% Finding procedure callers...\n", !IO),
    array.init(NPSs, [], ProcCallers0),
    array_foldl_from_1(construct_proc_callers(InitDeep),
        CallSiteDynamics, ProcCallers0, ProcCallers),
    maybe_report_msg(MaybeOutputStream,
        "% Done.\n", !IO),
    maybe_report_stats(MaybeOutputStream, !IO),

    maybe_report_msg(MaybeOutputStream,
        "% Constructing call site static map...\n", !IO),
    array.init(NCSDs, call_site_static_ptr(-1), CallSiteStaticMap0),
    array_foldl_from_1(construct_call_site_caller(InitDeep),
        ProcDynamics, CallSiteStaticMap0, CallSiteStaticMap),
    maybe_report_msg(MaybeOutputStream,
        "% Done.\n", !IO),
    maybe_report_stats(MaybeOutputStream, !IO),

    maybe_report_msg(MaybeOutputStream,
        "% Finding call site calls...\n", !IO),
    array.init(NCSSs, map.init, CallSiteCalls0),
    array_foldl_from_1(construct_call_site_calls(InitDeep),
        ProcDynamics, CallSiteCalls0, CallSiteCalls),
    maybe_report_msg(MaybeOutputStream,
        "% Done.\n", !IO),
    maybe_report_stats(MaybeOutputStream, !IO),

    maybe_report_msg(MaybeOutputStream,
        "% Propagating measurements up call graph...\n", !IO),

    array.init(NCSDs, zero_inherit_prof_info, CSDDesc0),
    array.init(NPDs, zero_own_prof_info, PDOwn0),
    array_foldl_from_1(sum_call_sites_in_proc_dynamic,
        CallSiteDynamics, PDOwn0, PDOwn),
    array.init(NPDs, zero_inherit_prof_info, PDDesc0),
    array.init(NPSs, zero_own_prof_info, PSOwn0),
    array.init(NPSs, zero_inherit_prof_info, PSDesc0),
    array.init(NCSSs, zero_own_prof_info, CSSOwn0),
    array.init(NCSSs, zero_inherit_prof_info, CSSDesc0),
    array.init(NPDs, map.init, PDCompTable0),
    array.init(NCSDs, map.init, CSDCompTable0),

    ModuleData = map.map_values(initialize_module_data, ModuleProcs),
    Deep0 = deep(InitStats, Machine, ScriptName, DataFileName, Root,
        CallSiteDynamics, ProcDynamics, CallSiteStatics, ProcStatics,
        CliqueIndex, Cliques, CliqueParents, CliqueMaybeChildren,
        ProcCallers, CallSiteStaticMap, CallSiteCalls,
        PDOwn, PDDesc0, CSDDesc0,
        PSOwn0, PSDesc0, CSSOwn0, CSSDesc0,
        PDCompTable0, CSDCompTable0, ModuleData),

    maybe_dump(DataFileName, DumpStages, 30,
        dump_deep(Deep0, DumpOptions), !IO),

    array_foldl_from_1(propagate_to_clique, Cliques, Deep0, Deep1),
    maybe_report_msg(MaybeOutputStream,
        "% Done.\n", !IO),
    maybe_report_stats(MaybeOutputStream, !IO),

    maybe_dump(DataFileName, DumpStages, 40,
        dump_deep(Deep1, DumpOptions), !IO),

    maybe_report_msg(MaybeOutputStream,
        "% Summarizing information...\n", !IO),
    summarize_proc_dynamics(Deep1, Deep2),
    summarize_call_site_dynamics(Deep2, Deep3),
    summarize_modules(Deep3, Deep),
    maybe_report_msg(MaybeOutputStream,
        "% Done.\n", !IO),
    maybe_report_stats(MaybeOutputStream, !IO),

    maybe_dump(DataFileName, DumpStages, 50,
        dump_deep(Deep, DumpOptions), !IO).

:- pred count_quanta(int::in, call_site_dynamic::in, int::in, int::out) is det.

count_quanta(_N, CSD, Quanta0, Quanta) :-
    Quanta = Quanta0 + quanta(CSD ^ csd_own_prof).

:- func initialize_module_data(string, list(proc_static_ptr)) = module_data.

initialize_module_data(_ModuleName, PSPtrs) =
    module_data(zero_own_prof_info, zero_inherit_prof_info, PSPtrs).

:- pred maybe_dump(string::in, list(string)::in, int::in,
    pred(io, io)::in(pred(di, uo) is det), io::di, io::uo) is det.

maybe_dump(BaseName, DumpStages, ThisStageNum, Action, !IO) :-
    string.int_to_string(ThisStageNum, ThisStage),
    (
        (
            list.member("all", DumpStages)
        ;
            list.member(ThisStage, DumpStages)
        )
    ->
        string.append_list([BaseName, ".deepdump.", ThisStage], FileName),
        io.open_output(FileName, OpenRes, !IO),
        (
            OpenRes = ok(FileStream),
            io.set_output_stream(FileStream, CurStream, !IO),
            Action(!IO),
            io.close_output(FileStream, !IO),
            io.set_output_stream(CurStream, _, !IO)
        ;
            OpenRes = error(Error),
            io.error_message(Error, Msg),
            io.format("%s: %s\n", [s(FileName), s(Msg)], !IO)
        )
    ;
        true
    ).

%-----------------------------------------------------------------------------%

:- pred record_css_containers_module_procs(int::in, proc_static::in,
    array(call_site_static)::array_di,
    array(call_site_static)::array_uo,
    map(string, list(proc_static_ptr))::in,
    map(string, list(proc_static_ptr))::out) is det.

record_css_containers_module_procs(PSI, PS, !CallSiteStatics, !ModuleProcs) :-
    CSSPtrs = PS ^ ps_sites,
    PSPtr = proc_static_ptr(PSI),
    array.max(CSSPtrs, MaxCS),
    record_css_containers_2(MaxCS, PSPtr, CSSPtrs, !CallSiteStatics),
    DeclModule = PS ^ ps_decl_module,
    ( map.search(!.ModuleProcs, DeclModule, PSPtrs0) ->
        svmap.det_update(DeclModule, [PSPtr | PSPtrs0], !ModuleProcs)
    ;
        svmap.det_insert(DeclModule, [PSPtr], !ModuleProcs)
    ).

:- pred record_css_containers_2(int::in, proc_static_ptr::in,
    array(call_site_static_ptr)::in,
    array(call_site_static)::array_di,
    array(call_site_static)::array_uo) is det.

record_css_containers_2(SlotNum, PSPtr, CSSPtrs, !CallSiteStatics) :-
    ( SlotNum >= 0 ->
        array.lookup(CSSPtrs, SlotNum, CSSPtr),
        lookup_call_site_statics(!.CallSiteStatics, CSSPtr, CSS0),
        CSS0 = call_site_static(PSPtr0, SlotNum0,
            Kind, LineNumber, GoalPath),
        require(unify(PSPtr0, proc_static_ptr(-1)),
            "record_css_containers_2: real proc_static_ptr"),
        require(unify(SlotNum0, -1),
            "record_css_containers_2: real slot_num"),
        CSS = call_site_static(PSPtr, SlotNum,
            Kind, LineNumber, GoalPath),
        update_call_site_statics(CSSPtr, CSS, !CallSiteStatics),
        record_css_containers_2(SlotNum - 1, PSPtr, CSSPtrs, !CallSiteStatics)
    ;
        true
    ).

%-----------------------------------------------------------------------------%

:- pred record_csd_containers_zeroed_pss(int::in, proc_dynamic::in,
    array(call_site_dynamic)::array_di,
    array(call_site_dynamic)::array_uo,
    array(proc_static)::array_di, array(proc_static)::array_uo) is det.

record_csd_containers_zeroed_pss(PDI, PD, !CallSiteDynamics, !ProcStatics) :-
    CSDArray = PD ^ pd_sites,
    PDPtr = proc_dynamic_ptr(PDI),
    flatten_call_sites(CSDArray, CSDPtrs, IsZeroed),
    record_csd_containers_2(PDPtr, CSDPtrs, !CallSiteDynamics),
    (
        IsZeroed = zeroed,
        PSPtr = PD ^ pd_proc_static,
        lookup_proc_statics(!.ProcStatics, PSPtr, PS0),
        PS = PS0 ^ ps_is_zeroed := zeroed,
        update_proc_statics(PSPtr, PS, !ProcStatics)
    ;
        IsZeroed = not_zeroed
    ).

:- pred record_csd_containers_2(proc_dynamic_ptr::in,
    list(call_site_dynamic_ptr)::in,
    array(call_site_dynamic)::array_di,
    array(call_site_dynamic)::array_uo) is det.

record_csd_containers_2(_, [], !CallSiteDynamics).
record_csd_containers_2(PDPtr, [CSDPtr | CSDPtrs], !CallSiteDynamics) :-
    lookup_call_site_dynamics(!.CallSiteDynamics, CSDPtr, CSD0),
    CSD0 = call_site_dynamic(CallerPDPtr0, CalleePDPtr, Own),
    require(unify(CallerPDPtr0, proc_dynamic_ptr(-1)),
        "record_csd_containers_2: real proc_dynamic_ptr"),
    CSD = call_site_dynamic(PDPtr, CalleePDPtr, Own),
    update_call_site_dynamics(CSDPtr, CSD, !CallSiteDynamics),
    record_csd_containers_2(PDPtr, CSDPtrs, !CallSiteDynamics).

%-----------------------------------------------------------------------------%

:- pred construct_clique_parents(initial_deep::in, array(clique_ptr)::in,
    int::in, clique_ptr::in,
    array(call_site_dynamic_ptr)::array_di,
    array(call_site_dynamic_ptr)::array_uo,
    array(maybe(clique_ptr))::array_di,
    array(maybe(clique_ptr))::array_uo) is det.

construct_clique_parents(InitDeep, CliqueIndex, PDI, CliquePtr,
        !CliqueParents, !CliqueMaybeChildren) :-
    ( PDI > 0 ->
        flat_call_sites(InitDeep ^ init_proc_dynamics,
            proc_dynamic_ptr(PDI), CSDPtrs),
        array_list_foldl2(
            construct_clique_parents_2(InitDeep, CliqueIndex, CliquePtr),
            CSDPtrs, !CliqueParents, !CliqueMaybeChildren)
    ;
        error("construct_clique_parents: invalid pdi")
    ).

:- pred construct_clique_parents_2(initial_deep::in, array(clique_ptr)::in,
    clique_ptr::in, call_site_dynamic_ptr::in,
    array(call_site_dynamic_ptr)::array_di,
    array(call_site_dynamic_ptr)::array_uo,
    array(maybe(clique_ptr))::array_di,
    array(maybe(clique_ptr))::array_uo) is det.

% :- pragma promise_pure(construct_clique_parents_2/8).

construct_clique_parents_2(InitDeep, CliqueIndex, ParentCliquePtr, CSDPtr,
        !CliqueParents, !CliqueMaybeChildren) :-
    CSDPtr = call_site_dynamic_ptr(CSDI),
    ( CSDI > 0 ->
        array.lookup(InitDeep ^ init_call_site_dynamics, CSDI, CSD),
        ChildPDPtr = CSD ^ csd_callee,
        ChildPDPtr = proc_dynamic_ptr(ChildPDI),
        ( ChildPDI > 0 ->
            array.lookup(CliqueIndex, ChildPDI, ChildCliquePtr),
            ( ChildCliquePtr \= ParentCliquePtr ->
                ChildCliquePtr = clique_ptr(ChildCliqueNum),
                % impure unsafe_perform_io(
                %   write_pdi_cn_csd(ChildPDI,
                %       ChildCliqueNum, CSDI)),
                svarray.set(ChildCliqueNum, CSDPtr, !CliqueParents),
                svarray.set(CSDI, yes(ChildCliquePtr), !CliqueMaybeChildren)
            ;
                true
            )
        ;
            true
        )
    ;
        true
    ).

%-----------------------------------------------------------------------------%

:- pred construct_proc_callers(initial_deep::in, int::in,
    call_site_dynamic::in,
    array(list(call_site_dynamic_ptr))::array_di,
    array(list(call_site_dynamic_ptr))::array_uo) is det.

construct_proc_callers(InitDeep, CSDI, CSD, !ProcCallers) :-
    PDPtr = CSD ^ csd_callee,
    ( valid_proc_dynamic_ptr_raw(InitDeep ^ init_proc_dynamics, PDPtr) ->
        lookup_proc_dynamics(InitDeep ^ init_proc_dynamics, PDPtr, PD),
        PSPtr = PD ^ pd_proc_static,
        lookup_proc_callers(!.ProcCallers, PSPtr, Callers0),
        Callers = [call_site_dynamic_ptr(CSDI) | Callers0],
        update_proc_callers(PSPtr, Callers, !ProcCallers)
    ;
        true
    ).

:- pred construct_call_site_caller(initial_deep::in, int::in, proc_dynamic::in,
    array(call_site_static_ptr)::array_di,
    array(call_site_static_ptr)::array_uo) is det.

construct_call_site_caller(InitDeep, _PDI, PD, !CallSiteStaticMap) :-
    PSPtr = PD ^ pd_proc_static,
    CSDArraySlots = PD ^ pd_sites,
    lookup_proc_statics(InitDeep ^ init_proc_statics, PSPtr, PS),
    CSSPtrs = PS ^ ps_sites,
    array.max(CSDArraySlots, MaxCS),
    construct_call_site_caller_2(MaxCS,
        InitDeep ^ init_call_site_dynamics, CSSPtrs, CSDArraySlots,
        !CallSiteStaticMap).

:- pred construct_call_site_caller_2(int::in, call_site_dynamics::in,
    array(call_site_static_ptr)::in,
    array(call_site_array_slot)::in,
    array(call_site_static_ptr)::array_di,
    array(call_site_static_ptr)::array_uo) is det.

construct_call_site_caller_2(SlotNum, Deep, CSSPtrs, CSDArraySlots,
        !CallSiteStaticMap) :-
    ( SlotNum >= 0 ->
        array.lookup(CSDArraySlots, SlotNum, CSDArraySlot),
        array.lookup(CSSPtrs, SlotNum, CSSPtr),
        (
            CSDArraySlot = slot_normal(CSDPtr),
            construct_call_site_caller_3(Deep, CSSPtr, -1, CSDPtr,
                !CallSiteStaticMap)
        ;
            CSDArraySlot = slot_multi(_, CSDPtrs),
            array_foldl_from_0(construct_call_site_caller_3(Deep, CSSPtr),
                CSDPtrs, !CallSiteStaticMap)
        ),
        construct_call_site_caller_2(SlotNum - 1, Deep, CSSPtrs,
            CSDArraySlots, !CallSiteStaticMap)
    ;
        true
    ).

:- pred construct_call_site_caller_3(call_site_dynamics::in,
    call_site_static_ptr::in, int::in, call_site_dynamic_ptr::in,
    array(call_site_static_ptr)::array_di,
    array(call_site_static_ptr)::array_uo) is det.

construct_call_site_caller_3(CallSiteDynamics, CSSPtr, _Dummy, CSDPtr,
        !CallSiteStaticMap) :-
    ( valid_call_site_dynamic_ptr_raw(CallSiteDynamics, CSDPtr) ->
        update_call_site_static_map(CSDPtr, CSSPtr, !CallSiteStaticMap)
    ;
        true
    ).

%-----------------------------------------------------------------------------%

:- pred construct_call_site_calls(initial_deep::in, int::in, proc_dynamic::in,
    array(map(proc_static_ptr, list(call_site_dynamic_ptr)))::array_di,
    array(map(proc_static_ptr, list(call_site_dynamic_ptr)))::array_uo)
    is det.

construct_call_site_calls(InitDeep, _PDI, PD, !CallSiteCalls) :-
    PSPtr = PD ^ pd_proc_static,
    CSDArraySlots = PD ^ pd_sites,
    array.max(CSDArraySlots, MaxCS),
    PSPtr = proc_static_ptr(PSI),
    array.lookup(InitDeep ^ init_proc_statics, PSI, PS),
    CSSPtrs = PS ^ ps_sites,
    CallSiteDynamics = InitDeep ^ init_call_site_dynamics,
    ProcDynamics = InitDeep ^ init_proc_dynamics,
    construct_call_site_calls_2(CallSiteDynamics, ProcDynamics, MaxCS,
        CSSPtrs, CSDArraySlots, !CallSiteCalls).

:- pred construct_call_site_calls_2(call_site_dynamics::in, proc_dynamics::in,
    int::in, array(call_site_static_ptr)::in,
    array(call_site_array_slot)::in,
    array(map(proc_static_ptr, list(call_site_dynamic_ptr)))::array_di,
    array(map(proc_static_ptr, list(call_site_dynamic_ptr)))::array_uo)
    is det.

construct_call_site_calls_2(CallSiteDynamics, ProcDynamics, SlotNum,
        CSSPtrs, CSDArraySlots, !CallSiteCalls) :-
    ( SlotNum >= 0 ->
        array.lookup(CSDArraySlots, SlotNum, CSDArraySlot),
        array.lookup(CSSPtrs, SlotNum, CSSPtr),
        (
            CSDArraySlot = slot_normal(CSDPtr),
            construct_call_site_calls_3(CallSiteDynamics,
                ProcDynamics, CSSPtr, -1, CSDPtr, !CallSiteCalls)
        ;
            CSDArraySlot = slot_multi(_, CSDPtrs),
            array_foldl_from_0(
                construct_call_site_calls_3(CallSiteDynamics,
                    ProcDynamics, CSSPtr),
                CSDPtrs, !CallSiteCalls)
        ),
        construct_call_site_calls_2(CallSiteDynamics, ProcDynamics,
            SlotNum - 1, CSSPtrs, CSDArraySlots, !CallSiteCalls)
    ;
        true
    ).

:- pred construct_call_site_calls_3(call_site_dynamics::in, proc_dynamics::in,
    call_site_static_ptr::in, int::in, call_site_dynamic_ptr::in,
    array(map(proc_static_ptr, list(call_site_dynamic_ptr)))::array_di,
    array(map(proc_static_ptr, list(call_site_dynamic_ptr)))::array_uo)
    is det.

construct_call_site_calls_3(CallSiteDynamics, ProcDynamics, CSSPtr,
        _Dummy, CSDPtr, !CallSiteCalls) :-
    CSDPtr = call_site_dynamic_ptr(CSDI),
    ( CSDI > 0 ->
        array.lookup(CallSiteDynamics, CSDI, CSD),
        PDPtr = CSD ^ csd_callee,
        PDPtr = proc_dynamic_ptr(PDI),
        array.lookup(ProcDynamics, PDI, PD),
        PSPtr = PD ^ pd_proc_static,

        CSSPtr = call_site_static_ptr(CSSI),
        array.lookup(!.CallSiteCalls, CSSI, CallMap0),
        ( map.search(CallMap0, PSPtr, CallList0) ->
            CallList = [CSDPtr | CallList0],
            map.det_update(CallMap0, PSPtr, CallList, CallMap)
        ;
            CallList = [CSDPtr],
            map.det_insert(CallMap0, PSPtr, CallList, CallMap)
        ),
        svarray.set(CSSI, CallMap, !CallSiteCalls)
    ;
        true
    ).

%-----------------------------------------------------------------------------%

:- pred sum_call_sites_in_proc_dynamic(int::in, call_site_dynamic::in,
    array(own_prof_info)::array_di, array(own_prof_info)::array_uo) is det.

sum_call_sites_in_proc_dynamic(_, CSD, !PDOwnArray) :-
    CalleeOwn = CSD ^ csd_own_prof,
    PDPtr = CSD ^ csd_callee,
    PDPtr = proc_dynamic_ptr(PDI),
    ( PDI > 0 ->
        array.lookup(!.PDOwnArray, PDI, ProcOwn0),
        ProcOwn = add_own_to_own(CalleeOwn, ProcOwn0),
        svarray.set(PDI, ProcOwn, !PDOwnArray)
    ;
        error("sum_call_sites_in_proc_dynamic: invalid pdptr")
    ).

%-----------------------------------------------------------------------------%

:- pred summarize_proc_dynamics(deep::in, deep::out) is det.

summarize_proc_dynamics(Deep0, Deep) :-
    PSOwnArray0 = Deep0 ^ ps_own,
    PSDescArray0 = Deep0 ^ ps_desc,
    array_foldl2_from_1(
        summarize_proc_dynamic(Deep0 ^ pd_own, Deep0 ^ pd_desc,
            Deep0 ^ pd_comp_table),
        Deep0 ^ proc_dynamics,
        copy(PSOwnArray0), PSOwnArray,
        copy(PSDescArray0), PSDescArray),
    Deep = ((Deep0
        ^ ps_own := PSOwnArray)
        ^ ps_desc := PSDescArray).

:- pred summarize_proc_dynamic(array(own_prof_info)::in,
    array(inherit_prof_info)::in, array(compensation_table)::in,
    int::in, proc_dynamic::in,
    array(own_prof_info)::array_di, array(own_prof_info)::array_uo,
    array(inherit_prof_info)::array_di, array(inherit_prof_info)::array_uo)
    is det.

summarize_proc_dynamic(PDOwnArray, PDDescArray, PDCompTableArray, PDI, PD,
        PSOwnArray0, PSOwnArray, PSDescArray0, PSDescArray) :-
    PSPtr = PD ^ pd_proc_static,
    PDPtr = proc_dynamic_ptr(PDI),
    lookup_pd_own(PDOwnArray, PDPtr, PDOwn),
    lookup_pd_desc(PDDescArray, PDPtr, PDDesc0),
    lookup_pd_comp_table(PDCompTableArray, PDPtr, PDCompTable),
    ( map.search(PDCompTable, PSPtr, InnerTotal) ->
        PDDesc = subtract_inherit_from_inherit(InnerTotal, PDDesc0)
    ;
        PDDesc = PDDesc0
    ),
    lookup_ps_own(PSOwnArray0, PSPtr, PSOwn0),
    lookup_ps_desc(PSDescArray0, PSPtr, PSDesc0),
    add_own_to_own(PDOwn, PSOwn0) = PSOwn,
    add_inherit_to_inherit(PDDesc, PSDesc0) = PSDesc,
    update_ps_own(PSPtr, PSOwn, u(PSOwnArray0), PSOwnArray),
    update_ps_desc(PSPtr, PSDesc, u(PSDescArray0), PSDescArray).

%-----------------------------------------------------------------------------%

:- pred summarize_call_site_dynamics(deep::in, deep::out) is det.

summarize_call_site_dynamics(Deep0, Deep) :-
    CSSOwnArray0 = Deep0 ^ css_own,
    CSSDescArray0 = Deep0 ^ css_desc,
    array_foldl2_from_1(
        summarize_call_site_dynamic(
            Deep0 ^ call_site_static_map,
            Deep0 ^ call_site_statics, Deep0 ^ csd_desc,
            Deep0 ^ csd_comp_table),
        Deep0 ^ call_site_dynamics,
        copy(CSSOwnArray0), CSSOwnArray,
        copy(CSSDescArray0), CSSDescArray),
    Deep = ((Deep0
        ^ css_own := CSSOwnArray)
        ^ css_desc := CSSDescArray).

:- pred summarize_call_site_dynamic(call_site_static_map::in,
    call_site_statics::in, array(inherit_prof_info)::in,
    array(compensation_table)::in, int::in, call_site_dynamic::in,
    array(own_prof_info)::array_di, array(own_prof_info)::array_uo,
    array(inherit_prof_info)::array_di, array(inherit_prof_info)::array_uo)
    is det.

summarize_call_site_dynamic(CallSiteStaticMap, CallSiteStatics,
        CSDDescs, CSDCompTableArray, CSDI, CSD,
        CSSOwnArray0, CSSOwnArray, CSSDescArray0, CSSDescArray) :-
    CSDPtr = call_site_dynamic_ptr(CSDI),
    lookup_call_site_static_map(CallSiteStaticMap, CSDPtr, CSSPtr),
    CSSPtr = call_site_static_ptr(CSSI),
    ( CSSI > 0 ->
        CSDOwn = CSD ^ csd_own_prof,
        lookup_csd_desc(CSDDescs, CSDPtr, CSDDesc0),
        lookup_csd_comp_table(CSDCompTableArray, CSDPtr, CSDCompTable),
        lookup_call_site_statics(CallSiteStatics, CSSPtr, CSS),
        ( map.search(CSDCompTable, CSS ^ css_container, InnerTotal) ->
            CSDDesc = subtract_inherit_from_inherit(InnerTotal, CSDDesc0)
        ;
            CSDDesc = CSDDesc0
        ),
        lookup_css_own(CSSOwnArray0, CSSPtr, CSSOwn0),
        lookup_css_desc(CSSDescArray0, CSSPtr, CSSDesc0),
        add_own_to_own(CSDOwn, CSSOwn0) = CSSOwn,
        add_inherit_to_inherit(CSDDesc, CSSDesc0) = CSSDesc,
        update_css_own(CSSPtr, CSSOwn, u(CSSOwnArray0), CSSOwnArray),
        update_css_desc(CSSPtr, CSSDesc, u(CSSDescArray0), CSSDescArray)
    ;
        error("summarize_call_site_dynamic: invalid css ptr")
    ).

%-----------------------------------------------------------------------------%

:- pred summarize_modules(deep::in, deep::out) is det.

summarize_modules(Deep0, Deep) :-
    ModuleData0 = Deep0 ^ module_data,
    ModuleData = map.map_values(summarize_module_costs(Deep0), ModuleData0),
    Deep = Deep0 ^ module_data := ModuleData.

:- func summarize_module_costs(deep, string, module_data) = module_data.

summarize_module_costs(Deep, _ModuleName, ModuleData0) = ModuleData :-
    ModuleData0 = module_data(Own0, Desc0, PSPtrs),
    list.foldl2(accumulate_ps_costs(Deep), PSPtrs, Own0, Own, Desc0, Desc),
    ModuleData = module_data(Own, Desc, PSPtrs).

:- pred accumulate_ps_costs(deep::in, proc_static_ptr::in,
    own_prof_info::in, own_prof_info::out,
    inherit_prof_info::in, inherit_prof_info::out) is det.

accumulate_ps_costs(Deep, PSPtr, Own0, Own, Desc0, Desc) :-
    deep_lookup_ps_own(Deep, PSPtr, PSOwn),
    deep_lookup_ps_desc(Deep, PSPtr, PSDesc),
    Own = add_own_to_own(Own0, PSOwn),
    Desc = add_inherit_to_inherit(Desc0, PSDesc).

%-----------------------------------------------------------------------------%

:- pred propagate_to_clique(int::in, list(proc_dynamic_ptr)::in,
    deep::in, deep::out) is det.

propagate_to_clique(CliqueNumber, Members, !Deep) :-
    array.lookup(!.Deep ^ clique_parents, CliqueNumber, ParentCSDPtr),
    list.foldl3(propagate_to_proc_dynamic(CliqueNumber, ParentCSDPtr), Members,
        !Deep, map.init, SumTable, map.init, OverrideMap),
    ( valid_call_site_dynamic_ptr(!.Deep, ParentCSDPtr) ->
        deep_lookup_call_site_dynamics(!.Deep, ParentCSDPtr, ParentCSD),
        ParentOwn = ParentCSD ^ csd_own_prof,
        deep_lookup_csd_desc(!.Deep, ParentCSDPtr, ParentDesc0),
        subtract_own_from_inherit(ParentOwn, ParentDesc0) = ParentDesc,
        deep_update_csd_desc(ParentCSDPtr, ParentDesc, !Deep),
        CSDCompTable = apply_override(OverrideMap, SumTable),
        deep_update_csd_comp_table(ParentCSDPtr, CSDCompTable, !Deep)
    ;
        true
    ).

:- pred propagate_to_proc_dynamic(int::in, call_site_dynamic_ptr::in,
    proc_dynamic_ptr::in, deep::in, deep::out,
    compensation_table::in, compensation_table::out,
    compensation_table::in, compensation_table::out) is det.

propagate_to_proc_dynamic(CliqueNumber, ParentCSDPtr, PDPtr, !Deep,
        !SumTable, !OverrideTable) :-
    flat_call_sites(!.Deep ^ proc_dynamics, PDPtr, CSDPtrs),
    list.foldl2(propagate_to_call_site(CliqueNumber, PDPtr),
        CSDPtrs, !Deep, map.init, PDCompTable),
    deep_update_pd_comp_table(PDPtr, PDCompTable, !Deep),

    deep_lookup_pd_desc(!.Deep, PDPtr, ProcDesc),
    deep_lookup_pd_own(!.Deep, PDPtr, ProcOwn),
    ProcTotal = add_own_to_inherit(ProcOwn, ProcDesc),

    !:SumTable = add_comp_tables(!.SumTable, PDCompTable),
    deep_lookup_proc_dynamics(!.Deep, PDPtr, PD),
    PSPtr = PD ^ pd_proc_static,
    deep_lookup_proc_statics(!.Deep, PSPtr, PS),
    ( PS ^ ps_is_zeroed = zeroed ->
        !:OverrideTable = add_to_override(!.OverrideTable, PSPtr, ProcTotal)
    ;
        true
    ),

    ( valid_call_site_dynamic_ptr(!.Deep, ParentCSDPtr) ->
        deep_lookup_csd_desc(!.Deep, ParentCSDPtr, ParentDesc0),
        ParentDesc = add_inherit_to_inherit(ParentDesc0, ProcTotal),
        deep_update_csd_desc(ParentCSDPtr, ParentDesc, !Deep)
    ;
        true
    ).

:- pred propagate_to_call_site(int::in, proc_dynamic_ptr::in,
    call_site_dynamic_ptr::in, deep::in, deep::out,
    compensation_table::in, compensation_table::out) is det.

propagate_to_call_site(CliqueNumber, PDPtr, CSDPtr, !Deep, !PDCompTable) :-
    deep_lookup_call_site_dynamics(!.Deep, CSDPtr, CSD),
    CalleeOwn = CSD ^ csd_own_prof,
    CalleePDPtr = CSD ^ csd_callee,
    deep_lookup_clique_index(!.Deep, CalleePDPtr, ChildCliquePtr),
    ChildCliquePtr = clique_ptr(ChildCliqueNumber),
    ( ChildCliqueNumber = CliqueNumber ->
        % We don't propagate profiling measurements along intra-clique calls.
        true
    ;
        deep_lookup_pd_desc(!.Deep, PDPtr, ProcDesc0),
        deep_lookup_csd_desc(!.Deep, CSDPtr, CalleeDesc),
        CalleeTotal = add_own_to_inherit(CalleeOwn, CalleeDesc),
        ProcDesc = add_inherit_to_inherit(ProcDesc0, CalleeTotal),
        deep_update_pd_desc(PDPtr, ProcDesc, !Deep),
        deep_lookup_csd_comp_table(!.Deep, CSDPtr, CSDCompTable),
        !:PDCompTable = add_comp_tables(!.PDCompTable, CSDCompTable)
    ).

%-----------------------------------------------------------------------------%

:- func add_comp_tables(compensation_table, compensation_table)
    = compensation_table.

add_comp_tables(CompTableA, CompTableB) = CompTable :-
    ( map.is_empty(CompTableA) ->
        CompTable = CompTableB
    ; map.is_empty(CompTableB) ->
        CompTable = CompTableA
    ;
        CompTable = map.union(add_inherit_to_inherit, CompTableA, CompTableB)
    ).

:- func apply_override(compensation_table, compensation_table)
    = compensation_table.

apply_override(CompTableA, CompTableB) = CompTable :-
    ( map.is_empty(CompTableA) ->
        CompTable = CompTableB
    ; map.is_empty(CompTableB) ->
        CompTable = CompTableA
    ;
        CompTable = map.union(select_override_comp, CompTableA, CompTableB)
    ).

:- func select_override_comp(inherit_prof_info, inherit_prof_info)
    = inherit_prof_info.

select_override_comp(OverrideComp, _) = OverrideComp.

:- func add_to_override(compensation_table,
    proc_static_ptr, inherit_prof_info) = compensation_table.

add_to_override(CompTable0, PSPtr, PDTotal) = CompTable :-
    ( map.search(CompTable0, PSPtr, Comp0) ->
        Comp = add_inherit_to_inherit(Comp0, PDTotal),
        map.det_update(CompTable0, PSPtr, Comp, CompTable)
    ;
        map.det_insert(CompTable0, PSPtr, PDTotal, CompTable)
    ).

%-----------------------------------------------------------------------------%

:- pred flat_call_sites(proc_dynamics::in, proc_dynamic_ptr::in,
    list(call_site_dynamic_ptr)::out) is det.

flat_call_sites(ProcDynamics, PDPtr, CSDPtrs) :-
    lookup_proc_dynamics(ProcDynamics, PDPtr, PD),
    CallSiteArray = PD ^ pd_sites,
    flatten_call_sites(CallSiteArray, CSDPtrs, _).

:- pred flatten_call_sites(array(call_site_array_slot)::in,
    list(call_site_dynamic_ptr)::out, is_zeroed::out) is det.

flatten_call_sites(CallSiteArray, CSDPtrs, IsZeroed) :-
    array.to_list(CallSiteArray, CallSites),
    list.foldl2(gather_call_site_csdptrs, CallSites, [], CSDPtrsList0,
        not_zeroed, IsZeroed),
    list.reverse(CSDPtrsList0, CSDPtrsList),
    list.condense(CSDPtrsList, CSDPtrs).

:- pred gather_call_site_csdptrs(call_site_array_slot::in,
    list(list(call_site_dynamic_ptr))::in,
    list(list(call_site_dynamic_ptr))::out,
    is_zeroed::in, is_zeroed::out) is det.

gather_call_site_csdptrs(Slot, CSDPtrs0, CSDPtrs1, IsZeroed0, IsZeroed) :-
    (
        Slot = slot_normal(CSDPtr),
        CSDPtr = call_site_dynamic_ptr(CSDI),
        ( CSDI > 0 ->
            CSDPtrs1 = [[CSDPtr] | CSDPtrs0]
        ;
            CSDPtrs1 = CSDPtrs0
        ),
        IsZeroed = IsZeroed0
    ;
        Slot = slot_multi(IsZeroed1, PtrArray),
        array.to_list(PtrArray, PtrList0),
        list.filter((pred(CSDPtr::in) is semidet :-
            CSDPtr = call_site_dynamic_ptr(CSDI),
            CSDI > 0
        ), PtrList0, PtrList1),
        CSDPtrs1 = [PtrList1 | CSDPtrs0],
        ( IsZeroed1 = zeroed ->
            IsZeroed = zeroed
        ;
            IsZeroed = IsZeroed0
        )
    ).

%-----------------------------------------------------------------------------%

:- pred maybe_report_stats(maybe(io.output_stream)::in,
    io::di, io::uo) is det.

% XXX: io.report_stats writes to stderr, which mdprof_cgi has closed.
% We want to write the report to _OutputStream, but the library doesn't
% support that yet.
%
% The stats are needed only when writing the deep profiling paper anyway.

maybe_report_stats(yes(_OutputStream), !IO).
    % io.report_stats("standard", !IO).
maybe_report_stats(no, !IO).

:- pred maybe_report_msg(maybe(io.output_stream)::in, string::in,
    io::di, io::uo) is det.

maybe_report_msg(yes(OutputStream), Msg, !IO) :-
    io.write_string(OutputStream, Msg, !IO),
    flush_output(OutputStream, !IO).
maybe_report_msg(no, _, !IO).

%-----------------------------------------------------------------------------%
:- end_module startup.
%-----------------------------------------------------------------------------%
