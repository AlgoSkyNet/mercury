%-----------------------------------------------------------------------------%
% vim: ts=4 sw=4 et ft=mercury
%-----------------------------------------------------------------------------%
% Copyright (C) 2005-2008, 2010-2012 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%-----------------------------------------------------------------------------%
%
% File: trace_counts.m.
% Main author: wangp.
% Modifications by zs and maclarty.
%
% This module defines predicates to read in the execution trace summaries
% generated by programs compiled using the compiler's tracing options.
%
%-----------------------------------------------------------------------------%

:- module mdbcomp.trace_counts.
:- interface.

:- import_module mdbcomp.goal_path.
:- import_module mdbcomp.prim_data.
:- import_module mdbcomp.sym_name.

:- import_module bool.
:- import_module io.
:- import_module list.
:- import_module map.
:- import_module maybe.
:- import_module set.

%-----------------------------------------------------------------------------%

:- type all_or_nonzero
    --->    user_all
            % The file contains counts for all labels from user-defined
            % procedures.

    ;       user_nonzero.
            % The file contains counts for all labels from user-defined
            % procedures, provided the count is nonzero.

:- type base_count_file_type
    --->    base_count_file_type(all_or_nonzero, string).
            % The first argument says whether we have all the counts;
            % the second gives the name of the program.

:- type trace_count_file_type
    --->    single_file(base_count_file_type)
            % The file contains counts from a single execution.

    ;       union_file(int, list(trace_count_file_type))
            % The file is a union of some other trace count files.
            % The number of test cases in the union is recorded, and
            % so is the set of kinds of trace count files they came from.
            % (We represent the set as a sorted list, because we write out
            % values of trace_count_file_type to files, and we don't want to
            % expose the implementation of sets.)

    ;       diff_file(trace_count_file_type, trace_count_file_type).
            % The file is a difference between two other trace count files.

:- func sum_trace_count_file_type(trace_count_file_type, trace_count_file_type)
    = trace_count_file_type.

:- type trace_counts == map(proc_label_in_context, proc_trace_counts).

:- type proc_label_in_context
    --->    proc_label_in_context(
                context_module_symname  :: sym_name,
                context_filename        :: string,
                proc_label              :: proc_label
            ).

:- type proc_trace_counts   == map(path_port, line_no_and_count).

:- type path_port
    --->    port_only(trace_port)
    ;       path_only(reverse_goal_path)
    ;       port_and_path(trace_port, reverse_goal_path).

:- type line_no_and_count
    --->    line_no_and_count(
                line_number             :: int,
                exec_count              :: int,
                num_tests               :: int
            ).

:- func make_path_port(reverse_goal_path, trace_port) = path_port.

:- pred summarize_trace_counts_list(list(trace_counts)::in, trace_counts::out)
    is det.

:- pred sum_trace_counts(trace_counts::in, trace_counts::in, trace_counts::out)
    is det.

:- pred diff_trace_counts(trace_counts::in, trace_counts::in,
    trace_counts::out) is det.

%-----------------------------------------------------------------------------%

:- type read_trace_counts_result
    --->    ok(trace_count_file_type, trace_counts)
    ;       syntax_error(string)
    ;       error_message(string)
    ;       open_error(io.error)
    ;       io_error(io.error).

    % read_trace_counts(FileName, Result, !IO):
    %
    % Read in the trace counts stored in FileName.
    %
:- pred read_trace_counts(string::in, read_trace_counts_result::out,
    io::di, io::uo) is det.

:- type read_trace_counts_list_result
    --->    list_ok(trace_count_file_type, trace_counts)
    ;       list_error_message(string).

    % read_trace_counts_list(ShowProgress, FileName, Result, !IO):
    %
    % Read the trace_counts in the files whose names appear in FileName.
    % The result is a union of all the trace counts.
    % If ShowProgress is yes then print the name of each file to the current
    % output stream just before it is read.
    %
:- pred read_trace_counts_list(bool::in, string::in,
    read_trace_counts_list_result::out, io::di, io::uo) is det.

    % read_trace_counts_source(FileName, Result, !IO):
    %
    % Read in trace counts stored in a given trace count file.
    %
:- pred read_trace_counts_source(string::in,
    read_trace_counts_list_result::out, io::di, io::uo) is det.

    % read_and_union_trace_counts(ShowProgress, FileNames, NumTests, TestKinds,
    %   TraceCounts, MaybeError, !IO):
    %
    % Invoke read_trace_counts_source for each of the supplied filenames, and
    % union the resulting trace counts. If there is a problem with reading in
    % the trace counts, MaybeError will be `yes' wrapped around the error
    % message. Otherwise, MaybeError will be `no', TraceCounts will contain
    % the union of the trace counts and NumTests will contain the number of
    % tests the trace counts come from.
    %
    % If the source is a list of files and ShowProgress is yes then
    % the name of each file read will be printed to the current output
    % stream just before it is read.
    %
:- pred read_and_union_trace_counts(bool::in, list(string)::in, int::out,
    set(trace_count_file_type)::out, trace_counts::out, maybe(string)::out,
    io::di, io::uo) is det.

    % write_trace_counts_to_file(FileType, TraceCounts, FileName, Result, !IO):
    %
    % Write the given trace counts to FileName in a format suitable for
    % reading with read_trace_counts/4.
    %
:- pred write_trace_counts_to_file(trace_count_file_type::in, trace_counts::in,
    string::in, io.res::out, io::di, io::uo) is det.

    % Write out the given proc_label.
    %
:- pred write_proc_label(proc_label::in, io::di, io::uo) is det.

:- pred string_to_trace_port(string, trace_port).
:- mode string_to_trace_port(in, out) is semidet.
:- mode string_to_trace_port(out, in) is det.

:- pred restrict_trace_counts_to_module(module_name::in, trace_counts::in,
    trace_counts::out) is det.

    % Return the number of tests cases used to generate the trace counts with
    % the given list of file types.
    %
:- func calc_num_tests(list(trace_count_file_type)) = int.

    % Return the number of tests used to create a trace counts file of the
    % given type.
    %
:- func num_tests_for_file_type(trace_count_file_type) = int.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module exception.
:- import_module int.
:- import_module lexer.
:- import_module require.
:- import_module string.
:- import_module term_io.
:- import_module univ.

%-----------------------------------------------------------------------------%

summarize_trace_counts_list(TraceCountsList, TraceCounts) :-
    ( if TraceCountsList = [TraceCountsPrime] then
        % optimize the common case
        TraceCounts = TraceCountsPrime
    else
        list.foldl(sum_trace_counts, TraceCountsList, map.init, TraceCounts)
    ).

sum_trace_counts(TraceCountsA, TraceCountsB, TraceCounts) :-
    map.union(sum_proc_trace_counts, TraceCountsA, TraceCountsB, TraceCounts).

:- pred sum_proc_trace_counts(proc_trace_counts::in, proc_trace_counts::in,
    proc_trace_counts::out) is det.

sum_proc_trace_counts(ProcTraceCountsA, ProcTraceCountsB, ProcTraceCounts) :-
    ProcTraceCounts = map.union(sum_counts_on_line,
        ProcTraceCountsA, ProcTraceCountsB).

:- func sum_counts_on_line(line_no_and_count, line_no_and_count)
    = line_no_and_count.

sum_counts_on_line(LC1, LC2) = LC :-
    % We don't check that LineNumber1 = LineNumber2 since that does not
    % necessarily represent an error. (Consider the case when the two trace
    % files are derived from sources that are identical except for the addition
    % of a comment.)

    LC1 = line_no_and_count(LineNumber1, Count1, NumTests1),
    LC2 = line_no_and_count(_LineNumber, Count2, NumTests2),
    LC = line_no_and_count(LineNumber1, Count1 + Count2,
        NumTests1 + NumTests2).

%-----------------------------------------------------------------------------%

diff_trace_counts(TraceCountsA, TraceCountsB, TraceCounts) :-
    map.foldl(diff_trace_counts_acc(TraceCountsB), TraceCountsA,
        map.init, TraceCounts).

:- pred diff_trace_counts_acc(trace_counts::in,
    proc_label_in_context::in, proc_trace_counts::in,
    trace_counts::in, trace_counts::out) is det.

diff_trace_counts_acc(TraceCountsB, ProcLabelInContextA, ProcTraceCountsA,
        !TraceCounts) :-
    ( if map.search(TraceCountsB, ProcLabelInContextA, ProcTraceCountsB) then
        ProcTraceCounts = diff_proc_counts(ProcTraceCountsA, ProcTraceCountsB),
        map.det_insert(ProcLabelInContextA, ProcTraceCounts, !TraceCounts)
    else
        map.det_insert(ProcLabelInContextA, ProcTraceCountsA, !TraceCounts)
    ).

:- func diff_proc_counts(proc_trace_counts, proc_trace_counts)
    = proc_trace_counts.

diff_proc_counts(ProcTraceCountsA, ProcTraceCountsB) = ProcTraceCounts :-
    map.foldl(diff_proc_counts_acc(ProcTraceCountsB), ProcTraceCountsA,
        map.init, ProcTraceCounts).

:- pred diff_proc_counts_acc(proc_trace_counts::in,
    path_port::in, line_no_and_count::in,
    proc_trace_counts::in, proc_trace_counts::out) is det.

diff_proc_counts_acc(ProcTraceCountsB, PathPortA, LineNoCountA,
        !ProcTraceCounts) :-
    ( if map.search(ProcTraceCountsB, PathPortA, LineNoCountB) then
        LineNoCount = diff_counts_on_line(LineNoCountA, LineNoCountB),
        map.det_insert(PathPortA, LineNoCount, !ProcTraceCounts)
    else
        map.det_insert(PathPortA, LineNoCountA, !ProcTraceCounts)
    ).

:- func diff_counts_on_line(line_no_and_count, line_no_and_count)
    = line_no_and_count.

diff_counts_on_line(LC1, LC2) = LC :-
    % We don't check that LineNumber1 = LineNumber2 since that does not
    % necessarily represent an error. (Consider the case when the two trace
    % files are derived from sources that are identical except for the addition
    % of a comment.)

    % The number of tests field doesn't make sense in the result of a diff
    % operation. We signal this fact by using a plainly dummy value.

    LC1 = line_no_and_count(LineNumber1, Count1, _NumTests1),
    LC2 = line_no_and_count(_LineNumber, Count2, _NumTests2),
    LC = line_no_and_count(LineNumber1, Count1 - Count2, -1).

%-----------------------------------------------------------------------------%

read_trace_counts_source(FileName, Result, !IO) :-
    read_trace_counts(FileName, ReadTCResult, !IO),
    (
        ReadTCResult = ok(FileType, TraceCount),
        Result = list_ok(FileType, TraceCount)
    ;
        ReadTCResult = io_error(IOError),
        ErrMsg = io.error_message(IOError),
        Result = list_error_message("IO error reading file " ++
            "`" ++ FileName ++ "': " ++ ErrMsg)
    ;
        ReadTCResult = open_error(IOError),
        ErrMsg = io.error_message(IOError),
        Result = list_error_message("IO error opening file " ++
            "`" ++ FileName ++ "': " ++ ErrMsg)
    ;
        ReadTCResult = syntax_error(ErrMsg),
        Result = list_error_message("Syntax error in file `" ++
            FileName ++ "': " ++ ErrMsg)
    ;
        ReadTCResult = error_message(ErrMsg),
        Result = list_error_message("Error reading trace counts " ++
            "from file `" ++ FileName ++ "': " ++ ErrMsg)
    ).

read_trace_counts_list(ShowProgress, FileName, Result, !IO) :-
    io.open_input(FileName, OpenResult, !IO),
    (
        OpenResult = ok(FileStream),
        read_trace_counts_list_stream(ShowProgress, union_file(0, []),
            map.init, FileName, FileStream, Result, !IO)
    ;
        OpenResult = error(IOError),
        Result = list_error_message("Error opening file `" ++ FileName ++
            "': " ++ string.string(IOError))
    ).

    % Same as read_trace_counts_list/5, but read the filenames containing
    % the trace_counts from the given stream.  MainFileName is the
    % name of the file being read and is only used for error messages.
    %
:- pred read_trace_counts_list_stream(bool::in, trace_count_file_type::in,
    trace_counts::in, string::in, io.input_stream::in,
    read_trace_counts_list_result::out, io::di, io::uo) is det.

read_trace_counts_list_stream(ShowProgress, FileType0, TraceCounts0,
        MainFileName, Stream, Result, !IO) :-
    io.read_line_as_string(Stream, ReadResult, !IO),
    (
        ReadResult = ok(Line),
        % Remove trailing whitespace:
        FileName = string.rstrip(Line),
        ( if
            % Ignore blank lines.
            FileName = ""
        then
            read_trace_counts_list_stream(ShowProgress, FileType0,
                TraceCounts0, MainFileName, Stream, Result, !IO)
        else
            (
                ShowProgress = yes,
                io.write_string(FileName, !IO),
                io.nl(!IO)
            ;
                ShowProgress = no
            ),
            read_trace_counts(FileName, ReadTCResult, !IO),
            (
                ReadTCResult = ok(FileType1, TraceCounts1),
                summarize_trace_counts_list([TraceCounts0, TraceCounts1],
                    TraceCounts),
                FileType = sum_trace_count_file_type(FileType0, FileType1),
                read_trace_counts_list_stream(ShowProgress, FileType,
                    TraceCounts, MainFileName, Stream, Result, !IO)
            ;
                ReadTCResult = io_error(IOError),
                ErrMsg = io.error_message(IOError),
                Result = list_error_message("I/O error reading file " ++
                    "`" ++ FileName ++ "': " ++ ErrMsg)
            ;
                ReadTCResult = open_error(IOError),
                ErrMsg = io.error_message(IOError),
                Result = list_error_message("I/O error opening file " ++
                    "`" ++ FileName ++ "': " ++ ErrMsg)
            ;
                ReadTCResult = syntax_error(ErrMsg),
                Result = list_error_message("Syntax error in file `" ++
                    FileName ++ "': " ++ ErrMsg)
            ;
                ReadTCResult = error_message(ErrMsg),
                Result = list_error_message("Error reading trace counts " ++
                    "from file `" ++ FileName ++ "': " ++ ErrMsg)
            )
        )
    ;
        ReadResult = error(Error),
        Result = list_error_message("IO error reading file " ++ "`" ++
            MainFileName ++ "': " ++ string.string(Error))
    ;
        ReadResult = eof,
        Result = list_ok(FileType0, TraceCounts0)
    ).

read_trace_counts(FileName, ReadResult, !IO) :-
    % XXX We should be using zcat here, to avoid deleting the gzipped file
    % and having to recreate it again. Unfortunately, we don't have any
    % facilities equivalent to popen in Unix, and I don't know how to
    % write one in a way that is portable to Windows. zs.
    % XXX ... and we certainly shouldn't be hardcoding the names of the
    % gzip / gunzip executables.  juliensf.
    ( if string.remove_suffix(FileName, ".gz", BaseName) then
        io.call_system("gunzip " ++ FileName, _UnzipResult, !IO),
        ActualFileName = BaseName,
        GzipCmd = "gzip " ++ BaseName
    else
        ActualFileName = FileName,
        GzipCmd = ""
    ),
    io.open_input(ActualFileName, Result, !IO),
    (
        Result = ok(FileStream),
        io.set_input_stream(FileStream, OldInputStream, !IO),
        io.read_line_as_string(IdReadResult, !IO),
        ( if
            IdReadResult = ok(FirstLine),
            string.rstrip(FirstLine) = trace_count_file_id
        then
            promise_equivalent_solutions [ReadResult, !:IO] (
                read_trace_counts_from_cur_stream(ReadResult, !IO)
            )
        else
            ReadResult = syntax_error("no trace count file id")
        ),
        io.set_input_stream(OldInputStream, _, !IO),
        io.close_input(FileStream, !IO)
    ;
        Result = error(IOError),
        ReadResult = open_error(IOError)
    ),
    ( if GzipCmd = "" then
        true
    else
        io.call_system(GzipCmd, _ZipResult, !IO)
    ).

:- func trace_count_file_id = string.

trace_count_file_id = "Mercury trace counts file".

:- pred read_trace_counts_from_cur_stream(read_trace_counts_result::out,
    io::di, io::uo) is cc_multi.

read_trace_counts_from_cur_stream(ReadResult, !IO) :-
    io.read(FileTypeResult, !IO),
    (
        FileTypeResult = ok(FileType),
        io.read_line_as_string(NewlineResult, !IO),
        ( if NewlineResult = ok("\n") then
            try_io(read_trace_counts_setup(map.init), Result, !IO),
            (
                Result = succeeded(TraceCounts),
                ReadResult = ok(FileType, TraceCounts)
            ;
                Result = exception(Exception),
                ( if Exception = univ(IOError) then
                    ReadResult = io_error(IOError)
                else if Exception = univ(Message) then
                    ReadResult = error_message(Message)
                else if Exception = univ(trace_count_syntax_error(Error)) then
                    ReadResult = syntax_error(Error)
                else
                    unexpected($module, $pred,
                        "unexpected exception type: " ++ string(Exception))
                )
            )
        else
            ReadResult = syntax_error("no info on trace count file type")
        )
    ;
        ( FileTypeResult = eof
        ; FileTypeResult = error(_, _)
        ),
        ReadResult = syntax_error("no info on trace count file type")
    ).

:- pred read_trace_counts_setup(trace_counts::in, trace_counts::out,
    io::di, io::uo) is det.

read_trace_counts_setup(!TraceCounts, !IO) :-
    io.get_line_number(LineNumber, !IO),
    io.read_line_as_string(Result, !IO),
    (
        Result = ok(Line),
        % The code in mercury_trace_counts.c always generates output that will
        % cause read_proc_trace_counts below to override these dummy module
        % and file names before they are referenced.
        CurModuleNameSym = unqualified(""),
        CurFileName = "",
        read_proc_trace_counts(LineNumber, Line, CurModuleNameSym, CurFileName,
            !TraceCounts, !IO)
    ;
        Result = eof
    ;
        Result = error(Error),
        throw(Error)
    ).

:- type trace_count_syntax_error
    --->    trace_count_syntax_error(string).

:- pred read_proc_trace_counts(int::in, string::in, sym_name::in, string::in,
    trace_counts::in, trace_counts::out, io::di, io::uo) is det.

read_proc_trace_counts(HeaderLineNumber, HeaderLine, CurModuleNameSym,
        CurFileName, !TraceCounts, !IO) :-
    lexer.string_get_token_list_max(HeaderLine, string.length(HeaderLine),
        TokenList, posn(HeaderLineNumber, 1, 0), _),
    ( if TokenList = token_cons(name(TokenName), _, TokenListRest) then
        ( if
            TokenName = "module",
            TokenListRest =
                token_cons(name(NextModuleName), _,
                token_nil)
        then
            NextModuleNameSym = string_to_sym_name(NextModuleName),
            io.read_line_as_string(Result, !IO),
            (
                Result = ok(Line),
                io.get_line_number(LineNumber, !IO),
                read_proc_trace_counts(LineNumber, Line,
                    NextModuleNameSym, CurFileName, !TraceCounts, !IO)
            ;
                Result = eof
            ;
                Result = error(Error),
                throw(Error)
            )
        else if
            TokenName = "file",
            TokenListRest =
                token_cons(name(NextFileName), _,
                token_nil)
        then
            io.read_line_as_string(Result, !IO),
            (
                Result = ok(Line),
                io.get_line_number(LineNumber, !IO),
                read_proc_trace_counts(LineNumber, Line,
                    CurModuleNameSym, NextFileName, !TraceCounts, !IO)
            ;
                Result = eof
            ;
                Result = error(Error),
                throw(Error)
            )
        else if
            % At the moment runtime/mercury_trace_base.c doesn't write out
            % data for unify, compare, index or init procedures.
            (
                TokenName = "pproc",
                TokenListRest =
                    token_cons(name(Name), _,
                    token_cons(integer(Arity), _,
                    token_cons(integer(Mode), _,
                    token_nil))),
                ProcLabel = ordinary_proc_label(CurModuleNameSym, pf_predicate,
                    CurModuleNameSym, Name, Arity, Mode)
            ;
                TokenName = "fproc",
                TokenListRest =
                    token_cons(name(Name), _,
                    token_cons(integer(Arity), _,
                    token_cons(integer(Mode), _,
                    token_nil))),
                ProcLabel = ordinary_proc_label(CurModuleNameSym, pf_function,
                    CurModuleNameSym, Name, Arity, Mode)
            ;
                TokenName = "pprocdecl",
                TokenListRest =
                    token_cons(name(DeclModuleName), _,
                    token_cons(name(Name), _,
                    token_cons(integer(Arity), _,
                    token_cons(integer(Mode), _,
                    token_nil)))),
                DeclModuleNameSym = string_to_sym_name(DeclModuleName),
                ProcLabel = ordinary_proc_label(CurModuleNameSym, pf_predicate,
                    DeclModuleNameSym, Name, Arity, Mode)
            ;
                TokenName = "fprocdecl",
                TokenListRest =
                    token_cons(name(DeclModuleName), _,
                    token_cons(name(Name), _,
                    token_cons(integer(Arity), _,
                    token_cons(integer(Mode), _,
                    token_nil)))),
                DeclModuleNameSym = string_to_sym_name(DeclModuleName),
                ProcLabel = ordinary_proc_label(CurModuleNameSym, pf_function,
                    DeclModuleNameSym, Name, Arity, Mode)
            )
        then
            ProcLabelInContext = proc_label_in_context(CurModuleNameSym,
                CurFileName, ProcLabel),
            % For whatever reason some of the trace counts for a single
            % procedure or function can be split over multiple spans.
            % We collate them as if they appeared in a single span.
            ( if map.remove(ProcLabelInContext, ProbeCounts, !TraceCounts) then
                StartCounts = ProbeCounts
            else
                StartCounts = map.init
            ),
            read_proc_trace_counts_2(ProcLabelInContext, StartCounts,
                !TraceCounts, !IO)
        else
            string.format("parse error on line %d of execution trace",
                [i(HeaderLineNumber)], Message),
            throw(trace_count_syntax_error(Message))
        )
    else
        string.format("parse error on line %d of execution trace",
            [i(HeaderLineNumber)], Message),
        throw(trace_count_syntax_error(Message))
    ).

:- pred read_proc_trace_counts_2(proc_label_in_context::in,
    proc_trace_counts::in, trace_counts::in, trace_counts::out,
    io::di, io::uo) is det.

read_proc_trace_counts_2(ProcLabelInContext, ProcCounts0, !TraceCounts, !IO) :-
    io.read_line_as_string(Result, !IO),
    (
        Result = ok(Line),
        ( if
            parse_path_port_line(Line, PathPort, LineNumber, ExecCount,
                NumTests)
        then
            LineNoAndCount = line_no_and_count(LineNumber, ExecCount,
                NumTests),
            map.det_insert(PathPort, LineNoAndCount, ProcCounts0, ProcCounts),
            read_proc_trace_counts_2(ProcLabelInContext, ProcCounts,
                !TraceCounts, !IO)
        else
            map.det_insert(ProcLabelInContext, ProcCounts0, !TraceCounts),
            io.get_line_number(LineNumber, !IO),
            CurModuleNameSym = ProcLabelInContext ^ context_module_symname,
            CurFileName = ProcLabelInContext ^ context_filename,
            read_proc_trace_counts(LineNumber, Line, CurModuleNameSym,
                CurFileName, !TraceCounts, !IO)
        )
    ;
        Result = eof,
        map.det_insert(ProcLabelInContext, ProcCounts0, !TraceCounts)
    ;
        Result = error(Error),
        throw(Error)
    ).

:- pred parse_path_port_line(string::in, path_port::out, int::out, int::out,
    int::out) is semidet.

parse_path_port_line(Line, PathPort, LineNumber, ExecCount, NumTests) :-
    Words = string.words(Line),
    ( if
        Words = [Word1, LineNumberStr | Rest],
        ( if string_to_trace_port(Word1, Port) then
            PathPortPrime = port_only(Port)
        else if Path = string_to_goal_path(Word1) then
            PathPortPrime = path_only(Path)
        else
            fail
        ),
        string.to_int(LineNumberStr, LineNumberPrime),
        parse_rest(Rest, ExecCountPrime, NumTestsPrime)
    then
        PathPort = PathPortPrime,
        LineNumber = LineNumberPrime,
        ExecCount = ExecCountPrime,
        NumTests = NumTestsPrime
    else
        Words = [PortStr, PathStr, LineNumberStr | Rest],
        string_to_trace_port(PortStr, Port),
        Path = string_to_goal_path(PathStr),
        PathPort = port_and_path(Port, Path),
        string.to_int(LineNumberStr, LineNumber),
        parse_rest(Rest, ExecCount, NumTests)
    ).

:- pred parse_rest(list(string)::in, int::out, int::out) is semidet.

parse_rest(Rest, ExecCount, NumTests) :-
    (
        Rest = [],
        ExecCount = 0,
        NumTests = 1
    ;
        Rest = [ExecCountStr],
        string.to_int(ExecCountStr, ExecCount),
        NumTests = 1
    ;
        Rest = [ExecCountStr, NumTestsStr],
        string.to_int(ExecCountStr, ExecCount),
        string.to_int(NumTestsStr, NumTests)
    ).

string_to_trace_port("CALL", port_call).
string_to_trace_port("EXIT", port_exit).
string_to_trace_port("REDO", port_redo).
string_to_trace_port("FAIL", port_fail).
string_to_trace_port("TAIL", port_tailrec_call).
string_to_trace_port("EXCP", port_exception).
string_to_trace_port("COND", port_ite_cond).
string_to_trace_port("THEN", port_ite_then).
string_to_trace_port("ELSE", port_ite_else).
string_to_trace_port("NEGE", port_neg_enter).
string_to_trace_port("NEGS", port_neg_success).
string_to_trace_port("NEGF", port_neg_failure).
string_to_trace_port("DSJF", port_disj_first).
string_to_trace_port("DSJL", port_disj_later).
string_to_trace_port("SWTC", port_switch).
string_to_trace_port("USER", port_user).

:- func string_to_goal_path(string) = reverse_goal_path is semidet.

string_to_goal_path(String) = Path :-
    string.prefix(String, "<"),
    string.suffix(String, ">"),
    string.length(String, Length),
    string.between(String, 1, Length - 1, SubString),
    rev_goal_path_from_string(SubString, Path).

    % This function should be kept in sync with the MR_named_count_port array
    % in runtime/mercury_trace_base.c.
    %
make_path_port(_GoalPath, port_call) = port_only(port_call).
make_path_port(_GoalPath, port_exit) = port_only(port_exit).
make_path_port(_GoalPath, port_redo) = port_only(port_redo).
make_path_port(_GoalPath, port_fail) = port_only(port_fail).
make_path_port(GoalPath, port_tailrec_call) = path_only(GoalPath).
make_path_port(_GoalPath, port_exception) = port_only(port_exception).
make_path_port(GoalPath, port_ite_cond) = path_only(GoalPath).
make_path_port(GoalPath, port_ite_then) = path_only(GoalPath).
make_path_port(GoalPath, port_ite_else) = path_only(GoalPath).
make_path_port(GoalPath, port_neg_enter) =
    port_and_path(port_neg_enter, GoalPath).
make_path_port(GoalPath, port_neg_success) =
    port_and_path(port_neg_success, GoalPath).
make_path_port(GoalPath, port_neg_failure) =
    port_and_path(port_neg_failure, GoalPath).
make_path_port(GoalPath, port_disj_first) = path_only(GoalPath).
make_path_port(GoalPath, port_disj_later) = path_only(GoalPath).
make_path_port(GoalPath, port_switch) = path_only(GoalPath).
make_path_port(_GoalPath, port_user) = port_only(port_user).

%-----------------------------------------------------------------------------%

read_and_union_trace_counts(ShowProgress, Files, NumTests, TestKinds,
        TraceCounts, MaybeError, !IO) :-
    read_and_union_trace_counts_2(ShowProgress, Files,
        union_file(0, []), FileType, map.init, TraceCounts, MaybeError, !IO),
    (
        FileType = union_file(NumTests, TestKindList),
        set.list_to_set(TestKindList, TestKinds)
    ;
        FileType = single_file(_),
        error("read_and_union_trace_counts: single_file")
    ;
        FileType = diff_file(_, _),
        error("read_and_union_trace_counts: diff_file")
    ).

:- pred read_and_union_trace_counts_2(bool::in,
    list(string)::in, trace_count_file_type::in, trace_count_file_type::out,
    trace_counts::in, trace_counts::out, maybe(string)::out,
    io::di, io::uo) is det.

read_and_union_trace_counts_2(_, [], !FileType, !TraceCounts, no, !IO).
read_and_union_trace_counts_2(ShowProgress, [FileName | FileNames],
        !FileType, !TraceCounts, MaybeError, !IO) :-
    (
        ShowProgress = yes,
        io.write_string(FileName, !IO),
        io.nl(!IO)
    ;
        ShowProgress = no
    ),
    read_trace_counts_source(FileName, TCResult, !IO),
    (
        TCResult = list_ok(FileType, NewTraceCounts),
        summarize_trace_counts_list([!.TraceCounts, NewTraceCounts],
            !:TraceCounts),
        !:FileType = sum_trace_count_file_type(!.FileType, FileType),
        read_and_union_trace_counts_2(ShowProgress, FileNames,
            !FileType, !TraceCounts, MaybeError, !IO)
    ;
        TCResult = list_error_message(Message),
        MaybeError = yes(Message)
    ).

%-----------------------------------------------------------------------------%

write_trace_counts_to_file(FileType, TraceCounts, FileName, Result, !IO) :-
    io.tell(FileName, TellResult, !IO),
    (
        TellResult = ok,
        Result = ok,
        io.write_string(trace_count_file_id, !IO),
        io.nl(!IO),
        write_trace_counts(FileType, TraceCounts, !IO),
        io.told(!IO)
    ;
        TellResult = error(Error),
        Result = error(Error)
    ).

:- pred write_trace_counts(trace_count_file_type::in,
    trace_counts::in, io::di, io::uo) is det.

write_trace_counts(FileType, TraceCounts, !IO) :-
    io.write(FileType, !IO),
    io.write_string(".", !IO),
    io.nl(!IO),
    map.foldl3(write_proc_label_and_file_trace_counts, TraceCounts,
        unqualified(""), _, "", _, !IO).

:- pred write_proc_label_and_file_trace_counts(proc_label_in_context::in,
    proc_trace_counts::in, sym_name::in, sym_name::out,
    string::in, string::out, io::di, io::uo) is det.

write_proc_label_and_file_trace_counts(ProcLabelInContext, PathPortCounts,
        !CurModuleNameSym, !CurFileName, !IO) :-
    ProcLabelInContext = proc_label_in_context(ModuleNameSym, FileName,
        ProcLabel),
    ( if ModuleNameSym = !.CurModuleNameSym then
        true
    else
        ModuleName = sym_name_to_string(ModuleNameSym),
        io.write_string("module ", !IO),
        term_io.quote_atom(ModuleName, !IO),
        io.write_string("\n", !IO),
        !:CurModuleNameSym = ModuleNameSym
    ),
    ( if FileName = !.CurFileName then
        true
    else
        io.write_string("file ", !IO),
        term_io.quote_atom(FileName, !IO),
        io.write_string("\n", !IO),
        !:CurFileName = FileName
    ),
    write_proc_label_and_check(ModuleNameSym, ProcLabel, !IO),
    map.foldl(write_path_port_count, PathPortCounts, !IO).

:- pred write_proc_label_and_check(sym_name::in, proc_label::in,
    io::di, io::uo) is det.

write_proc_label_and_check(ModuleNameSym, ProcLabel, !IO) :-
    (
        ProcLabel = ordinary_proc_label(DefModuleSym, _, _, _, _, _),
        require(unify(ModuleNameSym, DefModuleSym),
            "write_proc_label_and_check: module mismatch")
    ;
        % We don't record trace counts in special preds.
        ProcLabel = special_proc_label(_, _, _, _, _, _),
        error("write_proc_label: special_pred")
    ),
    write_proc_label(ProcLabel, !IO).

write_proc_label(ProcLabel, !IO) :-
    (
        ProcLabel = ordinary_proc_label(DefModuleSym, PredOrFunc,
            DeclModuleSym, Name, Arity, Mode),
        (
            PredOrFunc = pf_predicate,
            ( if DeclModuleSym = DefModuleSym then
                io.write_string("pproc ", !IO)
            else
                DeclModule = sym_name_to_string(DeclModuleSym),
                io.write_string("pprocdecl ", !IO),
                term_io.quote_atom(DeclModule, !IO),
                io.write_string(" ", !IO)
            )
        ;
            PredOrFunc = pf_function,
            ( if DeclModuleSym = DefModuleSym then
                io.write_string("fproc ", !IO)
            else
                DeclModule = sym_name_to_string(DeclModuleSym),
                io.write_string("fprocdecl ", !IO),
                term_io.quote_atom(DeclModule, !IO),
                io.write_string(" ", !IO)
            )
        ),
        term_io.quote_atom(Name, !IO),
        io.write_string(" ", !IO),
        io.write_int(Arity, !IO),
        io.write_string(" ", !IO),
        io.write_int(Mode, !IO),
        io.nl(!IO)
    ;
        % We don't record trace counts in special preds.
        ProcLabel = special_proc_label(_, _, _, _, _, _),
        error("write_proc_label: special_pred")
    ).

:- pred write_path_port_count(path_port::in, line_no_and_count::in,
    io::di, io::uo) is det.

write_path_port_count(port_only(Port),
        line_no_and_count(LineNo, ExecCount, NumTests), !IO) :-
    string_to_trace_port(PortStr, Port),
    io.write_strings([
        PortStr, " ",
        int_to_string(LineNo), " ",
        int_to_string(ExecCount), " ",
        int_to_string(NumTests), "\n"], !IO).
write_path_port_count(path_only(Path),
        line_no_and_count(LineNo, ExecCount, NumTests), !IO) :-
    io.write_strings([
        "<", rev_goal_path_to_string(Path), "> ",
        int_to_string(LineNo), " ",
        int_to_string(ExecCount), " ",
        int_to_string(NumTests), "\n"], !IO).
write_path_port_count(port_and_path(Port, Path),
        line_no_and_count(LineNo, ExecCount, NumTests), !IO) :-
    string_to_trace_port(PortStr, Port),
    io.write_strings([
        PortStr, " <", rev_goal_path_to_string(Path), "> ",
        int_to_string(LineNo), " ",
        int_to_string(ExecCount), " ",
        int_to_string(NumTests), "\n"], !IO).

%-----------------------------------------------------------------------------%

restrict_trace_counts_to_module(ModuleName, TraceCounts0, TraceCounts) :-
    map.foldl(restrict_trace_counts_2(ModuleName), TraceCounts0,
        map.init, TraceCounts).

:- pred restrict_trace_counts_2(module_name::in, proc_label_in_context::in,
    proc_trace_counts::in, trace_counts::in, trace_counts::out) is det.

restrict_trace_counts_2(ModuleName, ProcLabelInContext, ProcCounts,
        !TraceCounts) :-
    ProcLabel = ProcLabelInContext ^ proc_label,
    ( if ProcLabel = ordinary_proc_label(ModuleName, _, _, _, _, _) then
        map.det_insert(ProcLabelInContext, ProcCounts, !TraceCounts)
    else
        true
    ).

%-----------------------------------------------------------------------------%

calc_num_tests([]) = 0.
calc_num_tests([FileType | Rest]) =
    num_tests_for_file_type(FileType) + calc_num_tests(Rest).

num_tests_for_file_type(union_file(N, _)) = N.
num_tests_for_file_type(single_file(_)) = 1.
num_tests_for_file_type(diff_file(_, _)) = -1.

sum_trace_count_file_type(Type1, Type2) = UnionType :-
    (
        Type1 = single_file(_),
        Type2 = single_file(_),
        UnionType = union_file(2, sort_and_remove_dups([Type1, Type2]))
    ;
        Type1 = single_file(_),
        Type2 = union_file(N, IncludedTypes2),
        UnionType = union_file(N + 1,
            insert_into_list_as_set(IncludedTypes2, Type1))
    ;
        Type1 = single_file(_),
        Type2 = diff_file(_, _),
        UnionType = union_file(2, sort_and_remove_dups([Type1, Type2]))
    ;
        Type1 = union_file(N, IncludedTypes1),
        Type2 = single_file(_),
        UnionType = union_file(N + 1,
            insert_into_list_as_set(IncludedTypes1, Type2))
    ;
        Type1 = union_file(N1, IncludedTypes1),
        Type2 = union_file(N2, IncludedTypes2),
        UnionType = union_file(N1 + N2,
            sort_and_remove_dups(IncludedTypes1 ++ IncludedTypes2))
    ;
        Type1 = union_file(N, IncludedTypes1),
        Type2 = diff_file(_, _),
        UnionType = union_file(N + 1,
            insert_into_list_as_set(IncludedTypes1, Type2))
    ;
        Type1 = diff_file(_, _),
        Type2 = single_file(_),
        UnionType = union_file(2, sort_and_remove_dups([Type1, Type2]))
    ;
        Type1 = diff_file(_, _),
        Type2 = union_file(N, IncludedTypes2),
        UnionType = union_file(N + 1,
            insert_into_list_as_set(IncludedTypes2, Type1))
    ;
        Type1 = diff_file(_, _),
        Type2 = diff_file(_, _),
        UnionType = union_file(2, sort_and_remove_dups([Type1, Type2]))
    ).

:- func insert_into_list_as_set(list(T), T) = list(T).

insert_into_list_as_set(List0, Item) = List :-
    set.list_to_set(List0, Set0),
    set.insert(Item, Set0, Set),
    set.to_sorted_list(Set, List).
