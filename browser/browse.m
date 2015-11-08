%---------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sw=4 et
%---------------------------------------------------------------------------%
% Copyright (C) 1998-2007, 2009-2010 The University of Melbourne.
% This file may only be copied under the terms of the GNU Library General
% Public License - see the file COPYING.LIB in the Mercury distribution.
%---------------------------------------------------------------------------%
%
% File: browse.m.
% Author: aet.
% Stability: low.
%
% Implements a very simple term browser.
% There are a number of features that haven't been incorporated:
%
% - Scripting language that allows precise control over
%   how types are printed.
% - User preferences, which use the scripting language
%   to allow user control beyond the provided defaults.
% - Node expansion and contraction in the style of Windows Explorer.
%
%---------------------------------------------------------------------------%

:- module mdb.browse.
:- interface.

:- import_module mdb.browser_info.
:- import_module mdb.browser_term.

:- import_module io.
:- import_module list.
:- import_module maybe.
:- import_module univ.

%---------------------------------------------------------------------------%

    % The interactive term browser. The caller type will be `browse', and
    % the default format for the `browse' caller type will be used. Since
    % this predicate is exported to be used by C code, no browser term
    % mode function can be supplied.
    %
:- pred browse_browser_term_no_modes(browser_term::in,
    io.input_stream::in, io.output_stream::in,
    maybe_track_subterm(list(down_dir))::out,
    browser_persistent_state::in, browser_persistent_state::out,
    io::di, io::uo) is cc_multi.

    % The interactive term browser. The caller type will be `browse' and
    % the default format for the `browse' caller type will be used.
    %
:- pred browse_browser_term(browser_term::in,
    io.input_stream::in, io.output_stream::in,
    maybe(browser_mode_func)::in, maybe_track_subterm(list(down_dir))::out,
    browser_persistent_state::in, browser_persistent_state::out,
    io::di, io::uo) is cc_multi.

    % Dump the term as an XML file and launch the XML browser specified
    % by the xml_browser_cmd field in the browser_persistent_state.
    %
:- pred save_and_browse_browser_term_xml(browser_term::in,
    io.output_stream::in, io.output_stream::in,
    browser_persistent_state::in, io::di, io::uo) is cc_multi.

    % As above, except that the supplied format will override the default.
    % Again, this is exported to C code, so the browser term mode function
    % can't be supplied.
    %
:- pred browse_browser_term_format_no_modes(browser_term::in,
    io.input_stream::in, io.output_stream::in, portray_format::in,
    browser_persistent_state::in, browser_persistent_state::out,
    io::di, io::uo) is cc_multi.

    % As above, except that the supplied format will override the default.
    %
:- pred browse_browser_term_format(browser_term::in,
    io.input_stream::in, io.output_stream::in, portray_format::in,
    maybe(browser_mode_func)::in,
    browser_persistent_state::in, browser_persistent_state::out,
    io::di, io::uo) is cc_multi.

    % The browser interface for the external debugger. The caller type
    % will be `browse', and the default format will be used.
    % This version is exported for use in C code, so no browser term mode
    % function can be supplied.
    %
:- pred browse_external_no_modes(T::in, io.input_stream::in,
    io.output_stream::in,
    browser_persistent_state::in, browser_persistent_state::out,
    io::di, io::uo) is cc_multi.

    % The browser interface for the external debugger. The caller type
    % will be `browse', and the default format will be used.
    %
:- pred browse_external(T::in, io.input_stream::in,
    io.output_stream::in, maybe(browser_mode_func)::in,
    browser_persistent_state::in, browser_persistent_state::out,
    io::di, io::uo) is cc_multi.

    % The non-interactive term browser. The caller type should be either
    % `print' or `print_all'. The default portray format for that
    % caller type is used.
    %
:- pred print_browser_term(browser_term::in,
    io.output_stream::in, browse_caller_type::in,
    browser_persistent_state::in, io::di, io::uo) is cc_multi.

    % As above, except that the supplied format will override the default.
    %
:- pred print_browser_term_format(browser_term::in,
    io.output_stream::in, browse_caller_type::in, portray_format::in,
    browser_persistent_state::in, io::di, io::uo) is cc_multi.

    % Estimate the total term size, in characters, We count the number of
    % characters in the functor, plus two characters for each argument:
    % "(" and ")" for the first, and ", " for each of the rest, plus the
    % sizes of the arguments themselves. This is only approximate since it
    % doesn't take into account all the special cases such as operators.
    %
    % This predicate returns not the estimated total term size,
    % but the difference between the given maximum size the caller
    % is interested in and the estimated total term size.
    % This difference is positive if the term is smaller than the
    % maximum and negative if it is bigger. If the difference is
    % negative, term_size_left_from_max will return a negative difference
    % but the value will usually not be accurate, since in such cases
    % by definition the caller is not interested in the accurate value.
    %
:- pred term_size_left_from_max(univ::in, int::in, int::out) is cc_multi.
:- pred browser_term_size_left_from_max(browser_term::in,
    int::in, int::out) is cc_multi.

%---------------------------------------------------------------------------%

    % save_term_to_file(FileName, Format, BrowserTerm, Out, !IO):
    %
    % Save BrowserTerm to the file FileName. If there is an error,
    % print an error message to Out.
    %
    % The format of the saved term can be influenced by the Format
    % argument, but how this works is not specified.
    %
:- pred save_term_to_file(string::in, string::in, browser_term::in,
    io.output_stream::in, io::di, io::uo) is cc_multi.

    % save_term_to_file_xml(FileName, BrowserTerm, Out, !IO):
    %
    % Save BrowserTerm to FileName as an XML document. If there is an error,
    % print an error message to Out.
    %
:- pred save_term_to_file_xml(string::in, browser_term::in,
    io.output_stream::in, io::di, io::uo) is cc_multi.

    % Remove "/dir/../" sequences from a list of directories to yield
    % a form that lacks ".." entries.
    % If there are more ".." entries than normal entries, we return
    % the empty list.
    %
:- pred simplify_dirs(list(up_down_dir)::in, list(down_dir)::out) is det.

    % True if the given string can be used to cd to the return value of a
    % function.
    %
:- pred string_is_return_value_alias(string::in) is semidet.

    % For use in representing unbound head variables in the "print goal"
    % commands in the debugger.
:- type unbound
    --->    '_'.

%---------------------------------------------------------------------------%
%---------------------------------------------------------------------------%

:- implementation.

:- import_module mdb.parse.
:- import_module mdb.frame.
:- import_module mdb.sized_pretty.

:- import_module bool.
:- import_module char.
:- import_module deconstruct.
:- import_module getopt.
:- import_module int.
:- import_module map.
:- import_module pair.
:- import_module pretty_printer.
:- import_module stream.
:- import_module stream.string_writer.
:- import_module string.
:- import_module term_io.
:- import_module term_to_xml.
:- import_module type_desc.

%---------------------------------------------------------------------------%
%
% We export these predicates to C for use by the tracer:
% they are used in trace/mercury_trace_browse.c.
%

:- pragma foreign_export("C",
    browse_browser_term_no_modes(in, in, in, out, in, out, di, uo),
    "ML_BROWSE_browse_browser_term").
:- pragma foreign_export("C",
    browse_browser_term_format_no_modes(in, in, in, in, in, out, di, uo),
    "ML_BROWSE_browse_browser_term_format").
:- pragma foreign_export("C",
    browse_external_no_modes(in, in, in, in, out, di, uo),
    "ML_BROWSE_browse_external").
:- pragma foreign_export("C", print_browser_term(in, in, in, in, di, uo),
    "ML_BROWSE_print_browser_term").
:- pragma foreign_export("C",
    print_browser_term_format(in, in, in, in, in, di, uo),
    "ML_BROWSE_print_browser_term_format").

:- pragma foreign_export("C", save_term_to_file(in, in, in, in, di, uo),
    "ML_BROWSE_save_term_to_file").

:- pragma foreign_export("C", save_term_to_file_xml(in, in, in, di, uo),
    "ML_BROWSE_save_term_to_file_xml").

:- pragma foreign_export("C",
    save_and_browse_browser_term_xml(in, in, in, in, di, uo),
    "ML_BROWSE_browse_term_xml").

%---------------------------------------------------------------------------%
%
% Saving terms to files.
%

save_term_to_file(FileName, _Format, BrowserTerm, OutStream, !IO) :-
    % io.write_string(FileName, !IO),
    % io.nl(!IO),
    % io.write(BrowserTerm, !IO),
    % io.nl(!IO),
    io.tell(FileName, FileStreamRes, !IO),
    (
        FileStreamRes = ok,
        (
            BrowserTerm = plain_term(Term),
            save_univ(0, Term, !IO),
            io.nl(!IO)
        ;
            BrowserTerm = synthetic_term(Functor, Args, MaybeRes),
            io.write_string(Functor, !IO),
            io.write_string("(\n", !IO),
            save_args(1, Args, !IO),
            io.write_string("\n)\n", !IO),
            (
                MaybeRes = no
            ;
                MaybeRes = yes(Result),
                io.write_string("=\n", !IO),
                save_univ(1, Result, !IO),
                io.write_string("\n", !IO)
            )
        ),
        io.told(!IO)
    ;
        FileStreamRes = error(Error),
        io.error_message(Error, Msg),
        io.write_string(OutStream, Msg, !IO)
    ).

:- type xml_predicate_wrapper
    --->    predicate(
                predicate_name      :: string,
                predicate_arguments :: list(univ)
            ).

:- type xml_function_wrapper
    --->    function(
                function_name       :: string,
                function_arguments  :: list(univ),
                return_value        :: univ
            ).

save_term_to_file_xml(FileName, BrowserTerm, OutStream, !IO) :-
    maybe_save_term_to_file_xml(FileName, BrowserTerm, Result, !IO),
    (
        Result = ok(_)
    ;
        Result = error(Error),
        io.error_message(Error, Msg),
        io.write_string(OutStream, Msg, !IO),
        io.nl(!IO)
    ).

:- pred maybe_save_term_to_file_xml(string::in, browser_term::in,
    io.res(io.output_stream)::out, io::di, io::uo) is cc_multi.

maybe_save_term_to_file_xml(FileName, BrowserTerm, FileStreamRes, !IO) :-
    io.open_output(FileName, FileStreamRes, !IO),
    (
        FileStreamRes = ok(OutputStream),
        (
            BrowserTerm = plain_term(Univ),
            Term = univ_value(Univ),
            term_to_xml.write_xml_doc_general_cc(OutputStream, Term, simple,
                no_stylesheet,  no_dtd, _, !IO)
        ;
            BrowserTerm = synthetic_term(Functor, Args, MaybeRes),
            (
                MaybeRes = no,
                PredicateTerm = predicate(Functor, Args),
                term_to_xml.write_xml_doc_general_cc(OutputStream,
                    PredicateTerm, simple, no_stylesheet, no_dtd, _, !IO)
            ;
                MaybeRes = yes(Result),
                FunctionTerm = function(Functor, Args, Result),
                term_to_xml.write_xml_doc_general_cc(OutputStream,
                    FunctionTerm, simple, no_stylesheet, no_dtd, _, !IO)
            )
        ),
        io.close_output(OutputStream, !IO)
    ;
        FileStreamRes = error(_)
    ).

save_and_browse_browser_term_xml(Term, OutStream, ErrStream, State, !IO) :-
    MaybeXMLBrowserCmd = State ^ xml_browser_cmd,
    MaybeTmpFileName = State ^ xml_tmp_filename,
    (
        MaybeXMLBrowserCmd = yes(CommandStr),
        MaybeTmpFileName = yes(TmpFileName),
        io.write_string(OutStream, "Saving term to XML file...\n", !IO),
        maybe_save_term_to_file_xml(TmpFileName, Term, SaveResult, !IO),
        (
            SaveResult = ok(_),
            launch_xml_browser(OutStream, ErrStream, CommandStr, !IO)
        ;
            SaveResult = error(Error),
            io.error_message(Error, Msg),
            io.write_string(ErrStream,
                "Error opening file `" ++ TmpFileName ++ "': ", !IO),
            io.write_string(ErrStream, Msg, !IO),
            io.nl(!IO)
        )
    ;
        MaybeXMLBrowserCmd = yes(_),
        MaybeTmpFileName = no,
        io.write_string(ErrStream, "mdb: You need to issue a " ++
            "\"set xml_tmp_filename '<filename>'\" command first.\n", !IO)
    ;
        MaybeXMLBrowserCmd = no,
        MaybeTmpFileName = yes(_),
        io.write_string(ErrStream, "mdb: You need to issue a " ++
            "\"set xml_browser_cmd '<command>'\" command first.\n", !IO)
    ;
        MaybeXMLBrowserCmd = no,
        MaybeTmpFileName = no,
        io.write_string(ErrStream, "mdb: You need to issue a " ++
            "\"set xml_browser_cmd '<command>'\" command\n" ++
            "and a \"set xml_tmp_filename '<filename>'\" command first.\n",
            !IO)
    ).

:- pred launch_xml_browser(io.output_stream::in, io.output_stream::in,
    string::in, io::di, io::uo) is det.

launch_xml_browser(OutStream, ErrStream, CommandStr, !IO) :-
    io.write_string(OutStream, "Launching XML browser "
        ++ "(this may take some time) ...\n", !IO),
    % Flush the output stream, so output appears in the correct order
    % for tests where the `cat' command is used as the XML browser.
    io.flush_output(OutStream, !IO),
    io.call_system_return_signal(CommandStr, Result, !IO),
    (
        Result = ok(ExitStatus),
        (
            ExitStatus = exited(ExitCode),
            ( if ExitCode = 0 then
                true
            else
                io.write_string(ErrStream,
                    "mdb: The command `" ++ CommandStr ++
                    "' terminated with a non-zero exit code.\n", !IO)
            )
        ;
            ExitStatus = signalled(_),
            io.write_string(ErrStream, "mdb: The browser was killed.\n", !IO)
        )
    ;
        Result = error(Error),
        io.write_string(ErrStream, "mdb: Error launching browser: "
            ++ string.string(Error) ++ ".\n", !IO)
    ).

:- pred save_univ(int::in, univ::in, io::di, io::uo) is cc_multi.

save_univ(Indent, Univ, !IO) :-
    save_term(Indent, univ_value(Univ), !IO).

:- pred save_term(int::in, T::in, io::di, io::uo) is cc_multi.

save_term(Indent, Term, !IO) :-
    ( if dynamic_cast_to_list(Term, List) then
        (
            List = [],
            write_indent(Indent, !IO),
            io.write_string("[]", !IO)
        ;
            List = [_ | _],
            MakeUniv = (func(Element) = (ElementUniv) :-
                ElementUniv = univ(Element)
            ),
            Univs = list.map(MakeUniv, List),
            write_indent(Indent, !IO),
            io.write_string("[\n", !IO),
            save_args(Indent + 1, Univs, !IO),
            io.write_string("\n", !IO),
            write_indent(Indent, !IO),
            io.write_string("]", !IO)
        )
    else
        deconstruct(Term, include_details_cc, Functor, _Arity, Args),
        write_indent(Indent, !IO),
        io.write_string(Functor, !IO),
        (
            Args = []
        ;
            Args = [_ | _],
            io.write_string("(\n", !IO),
            save_args(Indent + 1, Args, !IO),
            io.write_string("\n", !IO),
            write_indent(Indent, !IO),
            io.write_string(")", !IO)
        )
    ).

:- some [T2] pred dynamic_cast_to_list(T1::in, list(T2)::out) is semidet.

dynamic_cast_to_list(X, L) :-
    % The code of this predicate is copied from pprint.m.
    [ArgTypeDesc] = type_args(type_of(X)),
    (_ `with_type` ArgType) `has_type` ArgTypeDesc,
    dynamic_cast(X, L `with_type` list(ArgType)).

:- pred save_args(int::in, list(univ)::in, io::di, io::uo) is cc_multi.

save_args(_Indent, [], !IO).
save_args(Indent, [Univ | Univs], !IO) :-
    save_univ(Indent, Univ, !IO),
    (
        Univs = []
    ;
        Univs = [_ | _],
        io.write_string(",\n", !IO),
        save_args(Indent, Univs, !IO)
    ).

:- pred write_indent(int::in, io::di, io::uo) is det.

write_indent(Indent, !IO) :-
    ( if Indent =< 0 then
        true
    else
        io.write_char(' ', !IO),
        write_indent(Indent - 1, !IO)
    ).

%---------------------------------------------------------------------------%
%
% Non-interactive display.
%

print_browser_term(Term, OutputStream, Caller, State, !IO) :-
    print_common(Term, OutputStream, Caller, no, State, !IO).

print_browser_term_format(Term, OutputStream, Caller, Format, State, !IO):-
    print_common(Term, OutputStream, Caller, yes(Format), State, !IO).

:- pred print_common(browser_term::in, io.output_stream::in,
    browse_caller_type::in, maybe(portray_format)::in,
    browser_persistent_state::in, io::di, io::uo) is cc_multi.

print_common(BrowserTerm, OutputStream, Caller, MaybeFormat, State, !IO):-
    Info = browser_info.init(BrowserTerm, Caller, MaybeFormat, no, State),
    io.set_output_stream(OutputStream, OldStream, !IO),
    browser_info.get_format(Info, Caller, MaybeFormat, Format),

    % For plain terms, we assume that the variable name has been printed
    % on the first part of the line. If the format is something other than
    % `flat', then we need to start on the next line.
    ( if
        BrowserTerm = plain_term(_),
        Format \= flat
    then
        io.nl(!IO)
    else
        true
    ),
    portray(debugger_internal, Caller, no, Info, !IO),
    io.set_output_stream(OldStream, _, !IO).

%---------------------------------------------------------------------------%
%
% Interactive display.
%

browse_browser_term_no_modes(Term, InputStream, OutputStream,
        MaybeTrack, !State, !IO) :-
    browse_common(debugger_internal, Term, InputStream, OutputStream,
        no, no, MaybeTrack, !State, !IO).

browse_browser_term(Term, InputStream, OutputStream, MaybeModeFunc,
        MaybeTrack, !State, !IO) :-
    browse_common(debugger_internal, Term, InputStream, OutputStream,
        no, MaybeModeFunc, MaybeTrack, !State, !IO).

browse_browser_term_format_no_modes(Term, InputStream, OutputStream,
        Format, !State, !IO) :-
    browse_common(debugger_internal, Term, InputStream, OutputStream,
        yes(Format), no, _, !State, !IO).

browse_browser_term_format(Term, InputStream, OutputStream,
        Format, MaybeModeFunc, !State, !IO) :-
    browse_common(debugger_internal, Term, InputStream, OutputStream,
        yes(Format), MaybeModeFunc, _, !State, !IO).

browse_external_no_modes(Term, InputStream, OutputStream, !State, !IO) :-
    browse_common(debugger_external, plain_term(univ(Term)),
        InputStream, OutputStream, no, no, _, !State, !IO).

browse_external(Term, InputStream, OutputStream, MaybeModeFunc, !State, !IO) :-
    browse_common(debugger_external, plain_term(univ(Term)),
        InputStream, OutputStream, no, MaybeModeFunc, _, !State, !IO).

:- pred browse_common(debugger::in, browser_term::in, io.input_stream::in,
    io.output_stream::in, maybe(portray_format)::in,
    maybe(browser_mode_func)::in, maybe_track_subterm(list(down_dir))::out,
    browser_persistent_state::in, browser_persistent_state::out,
    io::di, io::uo) is cc_multi.

browse_common(Debugger, Object, InputStream, OutputStream, MaybeFormat,
        MaybeModeFunc, MaybeTrack, !State, !IO) :-
    Info0 = browser_info.init(Object, browse, MaybeFormat, MaybeModeFunc,
        !.State),
    io.set_input_stream(InputStream, OldInputStream, !IO),
    io.set_output_stream(OutputStream, OldOutputStream, !IO),
    % startup_message,
    browse_main_loop(Debugger, Info0, Info, !IO),
    io.set_input_stream(OldInputStream, _, !IO),
    io.set_output_stream(OldOutputStream, _, !IO),
    MaybeTrack = Info ^ bri_maybe_track,
    !:State = Info ^ bri_state.

:- pred browse_main_loop(debugger::in, browser_info::in, browser_info::out,
    io::di, io::uo) is cc_multi.

browse_main_loop(Debugger, !Info, !IO) :-
    (
        Debugger = debugger_internal,
        parse.read_command(prompt, Command, !IO)
    ;
        Debugger = debugger_external,
        parse.read_command_external(Command, !IO)
    ),
    run_command(Debugger, Command, Quit, !Info, !IO),
    (
        Quit = yes,
        % write_string_debugger(Debugger, "quitting...\n", !IO)
        (
            Debugger = debugger_external,
            send_term_to_socket(browser_quit, !IO)
        ;
            Debugger = debugger_internal
        )
    ;
        Quit = no,
        browse_main_loop(Debugger, !Info, !IO)
    ).

:- pred startup_message(debugger::in, io::di, io::uo) is det.

startup_message(Debugger) -->
    write_string_debugger(Debugger, "-- Simple Mercury Term Browser.\n"),
    write_string_debugger(Debugger, "-- Type \"help\" for help.\n\n").

:- func prompt = string.

prompt = "browser> ".

:- pred run_command(debugger::in, command::in, bool::out,
    browser_info::in, browser_info::out, io::di, io::uo) is cc_multi.

run_command(Debugger, Command, Quit, !Info, !IO) :-
    % Please keep the code implementing commands in the same order
    % as the definition of the command type.

    % XXX The commands `set', `ls' and `print' should allow the format
    % to be specified by an option. In each case we instead pass `no' to
    % the respective handler.
    (
        Command = cmd_print(PrintOption, MaybePath),
        do_portray(Debugger, browse, PrintOption, !.Info, MaybePath, !IO),
        Quit = no
    ;
        Command = cmd_display,
        write_string_debugger(Debugger, "command not yet implemented\n", !IO),
        Quit = no
    ;
        Command = cmd_write,
        write_string_debugger(Debugger, "command not yet implemented\n", !IO),
        Quit = no
    ;
        Command = cmd_memory_addr(MaybePath),
        do_print_memory_addr(Debugger, !.Info, MaybePath, !IO),
        Quit = no
    ;
        Command = cmd_cd_no_path,
        set_path(root_rel([]), !Info),
        Quit = no
    ;
        Command = cmd_cd_path(Path),
        change_dir(!.Info ^ bri_dirs, Path, NewPwd),
        deref_subterm(!.Info ^ bri_term, NewPwd, Result),
        (
            Result = deref_result(_),
            !Info ^ bri_dirs := NewPwd
        ;
            Result = deref_error(OKPath, ErrorDir),
            report_deref_error(Debugger, OKPath, ErrorDir, !IO)
        ),
        Quit = no
    ;
        Command = cmd_pwd,
        write_down_path(Debugger, !.Info ^ bri_dirs, !IO),
        nl_debugger(Debugger, !IO),
        Quit = no
    ;
        Command = cmd_track(HowTrack, ShouldAssertInvalid, MaybePath),
        (
            MaybePath = yes(Path),
            change_dir(!.Info ^ bri_dirs, Path, NewPwd),
            deref_subterm(!.Info ^ bri_term, NewPwd, SubResult),
            (
                SubResult = deref_result(_),
                !Info ^ bri_maybe_track :=
                    track(HowTrack, ShouldAssertInvalid, NewPwd),
                Quit = yes
            ;
                SubResult = deref_error(_, _),
                write_string_debugger(Debugger,
                    "error: cannot track subterm\n", !IO),
                Quit = no
            )
        ;
            MaybePath = no,
            !Info ^ bri_maybe_track :=
                track(HowTrack, ShouldAssertInvalid, !.Info ^ bri_dirs),
            Quit = yes
        )
    ;
        Command = cmd_mode_query(Path),
        change_dir(!.Info ^ bri_dirs, Path, NewPwd),
        MaybeModeFunc = !.Info ^ bri_maybe_mode_func,
        write_term_mode_debugger(Debugger, MaybeModeFunc, NewPwd, !IO),
        Quit = no
    ;
        Command = cmd_mode_query_no_path,
        MaybeModeFunc = !.Info ^ bri_maybe_mode_func,
        write_term_mode_debugger(Debugger, MaybeModeFunc, !.Info ^ bri_dirs,
            !IO),
        Quit = no
    ;
        Command = cmd_param(ParamCmd),
        run_param_command(Debugger, ParamCmd, yes, !Info, !IO),
        Quit = no
    ;
        Command = cmd_help,
        help(Debugger, !IO),
        Quit = no
    ;
        Command = cmd_quit,
        Quit = yes
    ;
        Command = cmd_empty,
        Quit = no
    ;
        Command = cmd_unknown,
        write_string_debugger(Debugger,
            "Error: unknown command or syntax error.\n", !IO),
        write_string_debugger(Debugger, "Type \"help\" for help.\n", !IO),
        Quit = no
    ),
    (
        Debugger = debugger_external,
        send_term_to_socket(browser_end_command, !IO)
    ;
        Debugger = debugger_internal
    ).

:- pred do_portray(debugger::in, browse_caller_type::in,
    maybe(maybe_option_table(format_option))::in, browser_info::in,
    maybe(path)::in, io::di, io::uo) is cc_multi.

do_portray(Debugger, CallerType, MaybeMaybeOptionTable, Info, MaybePath,
        !IO) :-
    (
        MaybeMaybeOptionTable = no,
        portray_maybe_path(Debugger, CallerType, no, Info, MaybePath, !IO)
    ;
        MaybeMaybeOptionTable = yes(MaybeOptionTable),
        (
            MaybeOptionTable = ok(OptionTable),
            interpret_format_options(OptionTable, FormatResult),
            (
                FormatResult = ok(MaybeFormat),
                portray_maybe_path(Debugger, CallerType, MaybeFormat, Info,
                    MaybePath, !IO)
            ;
                FormatResult = error(Msg),
                write_string_debugger(Debugger, Msg, !IO),
                write_string_debugger(Debugger, "\n", !IO)
            )
        ;
            MaybeOptionTable = error(Msg),
            write_string_debugger(Debugger, Msg, !IO),
            write_string_debugger(Debugger, "\n", !IO)
        )
    ).

:- pred do_print_memory_addr(debugger::in, browser_info::in, maybe(path)::in,
    io::di, io::uo) is cc_multi.

do_print_memory_addr(Debugger, Info, MaybePath, !IO) :-
    Dirs0 = Info ^ bri_dirs,
    (
        MaybePath = no,
        Dirs = Dirs0
    ;
        MaybePath = yes(Path),
        change_dir(Dirs0, Path, Dirs)
    ),
    deref_subterm(Info ^ bri_term, Dirs, DerefResult),
    (
        DerefResult = deref_result(BrowserTerm),
        (
            BrowserTerm = plain_term(Univ),
            Value = univ_value(Univ),
            get_value_representation(Value, Addr),
            string.format("addr = %x\n", [i(Addr)], Str)
        ;
            BrowserTerm = synthetic_term(_, _, _),
            Str = "synthetic terms have no addresses\n"
        ),
        write_string_debugger(Debugger, Str, !IO)
    ;
        DerefResult = deref_error(OKPath, ErrorDir),
        report_deref_error(Debugger, OKPath, ErrorDir, !IO),
        nl_debugger(Debugger, !IO)
    ).

:- pred get_value_representation(T::in, int::out) is cc_multi.

:- pragma foreign_proc("C",
    get_value_representation(Value::in, Addr::out),
    [will_not_call_mercury, promise_pure],
"
    Addr = (MR_Integer) Value;
").

% Java doesn't support converting addresses to integers, so we
% just return zero.  For other backends the debugger doesn't yet
% work, so it doesn't matter what we return.
get_value_representation(_Value, X) :-
    cc_multi_equal(0, X).

:- pred interpret_format_options(option_table(format_option)::in,
    maybe_error(maybe(portray_format))::out) is det.

interpret_format_options(OptionTable, MaybeMaybeFormat) :-
    map.to_assoc_list(OptionTable, OptionAssocList),
    list.filter_map(bool_format_option_is_true, OptionAssocList,
        TrueFormatOptions),
    (
        TrueFormatOptions = [],
        MaybeMaybeFormat = ok(no)
    ;
        TrueFormatOptions = [FormatOption],
        (
            FormatOption = flat,
            Format = flat
        ;
            FormatOption = raw_pretty,
            Format = raw_pretty
        ;
            FormatOption = pretty,
            Format = pretty
        ;
            FormatOption = verbose,
            Format = verbose
        ),
        MaybeMaybeFormat = ok(yes(Format))
    ;
        TrueFormatOptions = [_, _ | _],
        MaybeMaybeFormat = error("error: inconsistent format options")
    ).

:- pred bool_format_option_is_true(pair(format_option, option_data)::in,
    format_option::out) is semidet.

bool_format_option_is_true(Format - bool(yes), Format).

:- pred help(debugger::in, io::di, io::uo) is det.

help(Debugger, !IO) :-
    string.append_list([
"Commands are:\n",
"\t[print|p|ls] [format_options] [path]\n",
"\t               -- print the specified subterm using the `browse' params\n",
% "\t[d|display] [path]\n",
% The display command is not yet implemented
% "\t[w|write] [path]\n",
% The write command is not yet implemented
"\t[addr|memory_addr] [path]\n",
"\t               -- print the raw memory address of the specified subterm\n",
"\tcd [path]      -- cd to the specified subterm (default is root)\n",
"\tcdr n path     -- repeatedly apply the cd command n times\n",
"\tpwd            -- print the path to the current subterm\n",
% How should we document the "[a|accurate]" option on [t|track|m|mark]?
"\t[t|track] [path]\n",
"\t               -- mark the specified subterm (default is current)\n",
"\t                  for tracking, and quit\n",
"\t[m|mark] [path]\n",
"\t               -- mark the specified subterm (default is current)\n",
"\t                  for tracking, asserting for the declarative debugger\n",
"\t                  that it makes the current goal invalid\n",
"\tmode [path]    -- show the mode of the specified subterm\n",
"\t                  (default is current)\n",
"\tformat [format_options] <flat|raw-pretty|verbose|pretty>\n",
"\t               -- set the format\n",
"\tdepth [format_param_options] <n>\n",
"\tsize  [format_param_options] <n>\n",
"\twidth [format_param_options] <n>\n",
"\tlines [format_param_options] <n>\n",
"\tnum_io_actions <n>\n",
"\t               -- set the named parameter value\n",
"\tparams         -- show format and parameter values\n",
"\tquit           -- quit browser\n",
"\thelp           -- show this help message\n",
"SICStus Prolog style commands are:\n",
"\tp              -- print\n",
"\t< n            -- set depth\n",
"\t^ [path]       -- cd to the specified subterm (default is root)\n",
"\t?              -- help\n",
"\th              -- help\n",
"\n",
"-- Paths can be Unix-style or SICStus-style: /2/3/1 or ^2^3^1\n",
"\n"],
        HelpMessage),
    write_string_debugger(Debugger, HelpMessage, !IO).

%---------------------------------------------------------------------------%
%
% Various pretty-print routines.
%

:- pred portray_maybe_path(debugger::in, browse_caller_type::in,
    maybe(portray_format)::in, browser_info::in,
    maybe(path)::in, io::di, io::uo) is cc_multi.

portray_maybe_path(Debugger, Caller, MaybeFormat, Info, MaybePath, !IO) :-
    (
        MaybePath = no,
        portray(Debugger, Caller, MaybeFormat, Info, !IO)
    ;
        MaybePath = yes(Path),
        portray_path(Debugger, Caller, MaybeFormat, Info, Path, !IO)
    ).

:- pred portray(debugger::in, browse_caller_type::in,
    maybe(portray_format)::in, browser_info::in,
    io::di, io::uo) is cc_multi.

portray(Debugger, Caller, MaybeFormat, Info, !IO) :-
    browser_info.get_format(Info, Caller, MaybeFormat, Format),
    browser_info.get_format_params(Info, Caller, Format, Params),
    deref_subterm(Info ^ bri_term, Info ^ bri_dirs, SubResult),
    (
        SubResult = deref_result(SubUniv),
        (
            Format = flat,
            portray_flat(Debugger, SubUniv, Params, !IO)
        ;
            Format = raw_pretty,
            portray_raw_pretty(Debugger, SubUniv, Params, !IO)
        ;
            Format = verbose,
            portray_verbose(Debugger, SubUniv, Params, !IO)
        ;
            Format = pretty,
            portray_pretty(Debugger, SubUniv, Params, !IO)
        )
    ;
        SubResult = deref_error(OKPath, ErrorDir),
        report_deref_error(Debugger, OKPath, ErrorDir, !IO)
        % write_string_debugger(Debugger, "error: no such subterm")
    ),
    nl_debugger(Debugger, !IO).

:- pred portray_path(debugger::in, browse_caller_type::in,
    maybe(portray_format)::in, browser_info::in, path::in,
    io::di, io::uo) is cc_multi.

portray_path(Debugger, Caller, MaybeFormat, Info0, Path, !IO) :-
    set_path(Path, Info0, Info),
    portray(Debugger, Caller, MaybeFormat, Info, !IO).

:- pred portray_flat(debugger::in, browser_term::in, format_params::in,
    io::di, io::uo) is cc_multi.

portray_flat(Debugger, BrowserTerm, Params, !IO) :-
    % io.write handles the special cases such as lists, operators, etc better,
    % so we prefer to use it if we can. However, io.write doesn't have
    % a depth or size limit, so we need to check the size first; if the term
    % is small enough, we use string_writer.write (actually
    % string_writer.write_univ), otherwise we use term_to_string/4.
    %
    % XXX This ignores the maximum number of lines.

    browser_term_size_left_from_max(BrowserTerm, max_print_size,
        RemainingSize),
    ( if RemainingSize >= 0 then
        portray_flat_write_browser_term(BrowserTerm, !IO)
    else
        io.get_stream_db(StreamDb, !IO),
        BrowserDb = browser_db(StreamDb),
        browser_term_to_string(BrowserDb, BrowserTerm, Params ^ size,
            Params ^ depth, Str),
        write_string_debugger(Debugger, Str, !IO)
    ).

:- pred portray_flat_write_browser_term(browser_term::in,
    io::di, io::uo) is cc_multi.

portray_flat_write_browser_term(plain_term(Univ), !IO) :-
    io.output_stream(Stream, !IO),
    string_writer.write_univ(Stream, include_details_cc, Univ, !IO).
portray_flat_write_browser_term(synthetic_term(Functor, Args, MaybeReturn),
        !IO) :-
    io.write_string(Functor, !IO),
    io.output_stream(Stream, !IO),
    (
        Args = []
    ;
        Args = [_ | _],
        io.write_string("(", !IO),
        io.write_list(Args, ", ", write_univ_or_unbound(Stream), !IO),
        io.write_string(")", !IO)
    ),
    (
        MaybeReturn = yes(Return),
        io.write_string(" = ", !IO),
        string_writer.write_univ(Stream, include_details_cc, Return, !IO)
    ;
        MaybeReturn = no
    ).

:- pred portray_verbose(debugger::in, browser_term::in, format_params::in,
    io::di, io::uo) is cc_multi.

portray_verbose(Debugger, BrowserTerm, Params, !IO) :-
    io.get_stream_db(StreamDb, !IO),
    BrowserDb = browser_db(StreamDb),
    browser_term_to_string_verbose(BrowserDb, BrowserTerm, Params ^ size,
        Params ^ depth, Params ^ width, Params ^ lines, Str),
    write_string_debugger(Debugger, Str, !IO).

:- pred portray_pretty(debugger::in, browser_term::in, format_params::in,
    io::di, io::uo) is det.

portray_pretty(Debugger, BrowserTerm, Params, !IO) :-
    browser_term_to_string_pretty(Debugger, BrowserTerm, Params ^ width,
        Params ^ lines, Params ^ size, Params ^ depth, !IO).

:- pred portray_raw_pretty(debugger::in, browser_term::in, format_params::in,
    io::di, io::uo) is cc_multi.

portray_raw_pretty(Debugger, BrowserTerm, Params, !IO) :-
    io.get_stream_db(StreamDb, !IO),
    BrowserDb = browser_db(StreamDb),
    sized_pretty.browser_term_to_string_line(BrowserDb, BrowserTerm,
        Params ^ width, Params ^ lines, Str),
    write_string_debugger(Debugger, Str, !IO).

    % The maximum estimated size for which we use `io.write'.
    %
:- func max_print_size = int.

max_print_size = 60.

term_size_left_from_max(Univ, MaxSize, RemainingSize) :-
    ( if MaxSize < 0 then
        RemainingSize = MaxSize
    else
        deconstruct.limited_deconstruct_cc(univ_value(Univ), MaxSize,
            MaybeFunctorArityArgs),
        (
            MaybeFunctorArityArgs = yes({Functor, Arity, Args}),
            string.length(Functor, FunctorSize),
            % "()", plus Arity-1 times ", "
            PrincipalSize = FunctorSize + Arity * 2,
            MaxArgsSize = MaxSize - PrincipalSize,
            list.foldl(term_size_left_from_max, Args,
                MaxArgsSize, RemainingSize)
        ;
            MaybeFunctorArityArgs = no,
            RemainingSize = -1
        )
    ;
        RemainingSize = -1
    ).

browser_term_size_left_from_max(BrowserTerm, MaxSize, RemainingSize) :-
    (
        BrowserTerm = plain_term(Univ),
        term_size_left_from_max(Univ, MaxSize, RemainingSize)
    ;
        BrowserTerm = synthetic_term(Functor, Args, MaybeReturn),
        string.length(Functor, FunctorSize),
        list.length(Args, Arity),
        (
            MaybeReturn = yes(_),
            % "()", " = ", plus Arity-1 times ", "
            PrincipalSize = FunctorSize + Arity * 2 + 3
        ;
            MaybeReturn = no,
            % "()", plus Arity-1 times ", "
            PrincipalSize = FunctorSize + Arity * 2
        ),
        MaxArgsSize = MaxSize - PrincipalSize,
        list.foldl(term_size_left_from_max, Args, MaxArgsSize, RemainingSize)
    ).

:- pred write_univ_or_unbound(io.output_stream::in, univ::in, io::di, io::uo)
    is cc_multi.

write_univ_or_unbound(Stream, Univ, !IO) :-
    ( if univ_to_type(Univ, _ `with_type` unbound) then
        io.write_char(Stream, '_', !IO)
    else
        string_writer.write_univ(Stream, include_details_cc, Univ, !IO)
    ).

:- pred report_deref_error(debugger::in, list(down_dir)::in, down_dir::in,
    io::di, io::uo) is det.

report_deref_error(Debugger, OKPath, ErrorDir, !IO) :-
    write_string_debugger(Debugger, "error: ", !IO),
    (
        OKPath = [_ | _],
        Context = "in subdir " ++ down_dirs_to_string(OKPath) ++ ": ",
        write_string_debugger(Debugger, Context, !IO)
    ;
        OKPath = []
    ),
    Msg = "there is no subterm " ++ down_dir_to_string(ErrorDir) ++ "\n",
    write_string_debugger(Debugger, Msg, !IO).

%---------------------------------------------------------------------------%
%
% Single-line representation of a term.
%

:- pred browser_term_to_string(browser_db::in, browser_term::in,
    int::in, int::in, string::out) is cc_multi.

browser_term_to_string(BrowserDb, BrowserTerm, MaxSize, MaxDepth, Str) :-
    CurSize = 0,
    CurDepth = 0,
    browser_term_to_string_2(BrowserDb, BrowserTerm,
        MaxSize, CurSize, _NewSize, MaxDepth, CurDepth, Str).

    % Note: When the size limit is reached, we simply display further subterms
    % compressed. This is consistent with the User's Guide, which describes
    % the size limit as a "suggested maximum".
    %
:- pred browser_term_to_string_2(browser_db::in, browser_term::in,
    int::in, int::in, int::out, int::in, int::in, string::out) is cc_multi.

browser_term_to_string_2(BrowserDb, BrowserTerm, MaxSize, CurSize, NewSize,
        MaxDepth, CurDepth, Str) :-
    limited_deconstruct_browser_term_cc(BrowserDb, BrowserTerm, MaxSize,
        MaybeFunctorArityArgs, MaybeReturn),
    ( if
        CurSize < MaxSize,
        CurDepth < MaxDepth,
        MaybeFunctorArityArgs = yes({Functor, _Arity, Args})
    then
        browser_term_to_string_3(BrowserDb, Functor, Args, MaybeReturn,
            MaxSize, CurSize, NewSize, MaxDepth, CurDepth, Str)
    else
        browser_term_compress(BrowserDb, BrowserTerm, Str),
        NewSize = CurSize
    ).

:- pred browser_term_to_string_3(browser_db::in, string::in,
    list(univ)::in, maybe(univ)::in, int::in, int::in, int::out,
    int::in, int::in, string::out) is cc_multi.

browser_term_to_string_3(BrowserDb, Functor, Args, MaybeReturn,
        MaxSize, Size0, Size, MaxDepth, Depth0, Str) :-
    ( if
        Functor = "[|]",
        Args = [ListHead, ListTail],
        MaybeReturn = no
    then
        % For the purposes of size and depth, we treat lists as if they consist
        % of one functor plus an argument for each element of the list.
        Size1 = Size0 + 1,
        Depth1 = Depth0 + 1,
        browser_term_to_string_2(BrowserDb, plain_term(ListHead),
            MaxSize, Size1, Size2, MaxDepth, Depth1, HeadStr),
        list_tail_to_string_list(BrowserDb, ListTail,
            MaxSize, Size2, Size, MaxDepth, Depth1, TailStrs),
        list.append(TailStrs, ["]"], Strs),
        string.append_list(["[", HeadStr | Strs], Str)
    else if
        Functor = "[]",
        Args = [],
        MaybeReturn = no
    then
        Size = Size0 + 1,
        Str = "[]"
    else
        Size1 = Size0 + 1,
        Depth1 = Depth0 + 1,
        args_to_string_list(BrowserDb, Args, MaxSize, Size1, Size2,
            MaxDepth, Depth1, ArgStrs),
        BracketedArgsStr = bracket_string_list(ArgStrs),
        (
            MaybeReturn = yes(Return),
            browser_term_to_string_2(BrowserDb, plain_term(Return),
                MaxSize, Size2, Size, MaxDepth, Depth1, ReturnStr),
            string.append_list([Functor, BracketedArgsStr, " = ", ReturnStr],
                Str)
        ;
            MaybeReturn = no,
            Size = Size2,
            string.append_list([Functor, BracketedArgsStr], Str)
        )
    ).

:- pred list_tail_to_string_list(browser_db::in, univ::in,
    int::in, int::in, int::out, int::in, int::in, list(string)::out)
    is cc_multi.

list_tail_to_string_list(BrowserDb, TailUniv, MaxSize, Size0, Size,
        MaxDepth, Depth0, TailStrs) :-
    % We want the limit to be at least two to ensure that the limited
    % deconstruct won't fail for any list term.
    Limit = max(MaxSize, 2),
    limited_deconstruct_browser_term_cc(BrowserDb, plain_term(TailUniv),
        Limit, MaybeFunctorArityArgs, MaybeReturn),
    (
        MaybeFunctorArityArgs = yes({Functor, _Arity, Args}),
        ( if
            Functor = "[]",
            Args = [],
            MaybeReturn = no
        then
            Size = Size0,
            TailStrs = []
        else if
            Functor = "[|]",
            Args = [ListHead, ListTail],
            MaybeReturn = no
        then
            ( if
                Size0 < MaxSize,
                Depth0 < MaxDepth
            then
                browser_term_to_string_2(BrowserDb, plain_term(ListHead),
                    MaxSize, Size0, Size1, MaxDepth, Depth0, HeadStr),
                list_tail_to_string_list(BrowserDb, ListTail, MaxSize,
                    Size1, Size, MaxDepth, Depth0, TailStrs0),
                TailStrs = [", ", HeadStr | TailStrs0]
            else
                Size = Size0,
                TailStrs = [", ..."]
            )
        else
            ( if
                Size0 < MaxSize,
                Depth0 < MaxDepth
            then
                browser_term_to_string_3(BrowserDb, Functor, Args, MaybeReturn,
                    MaxSize, Size0, Size, MaxDepth, Depth0, TailStr),
                TailStrs = [" | ", TailStr]
            else
                Size = Size0,
                browser_term_compress(BrowserDb, plain_term(TailUniv),
                    TailCompressedStr),
                TailStrs = [" | ", TailCompressedStr]
            )
        )
    ;
        MaybeFunctorArityArgs = no,
        Size = Size0,
        browser_term_compress(BrowserDb, plain_term(TailUniv),
            TailCompressedStr),
        TailStrs = [" | ", TailCompressedStr]
    ).

:- pred args_to_string_list(browser_db::in, list(univ)::in,
    int::in, int::in, int::out, int::in, int::in, list(string)::out)
    is cc_multi.

args_to_string_list(_BrowserDb, [], _MaxSize, CurSize, NewSize,
        _MaxDepth, _CurDepth, Strs) :-
    Strs = [],
    NewSize = CurSize.
args_to_string_list(BrowserDb, [Univ | Univs], MaxSize, CurSize, NewSize,
        MaxDepth, CurDepth, Strs) :-
    browser_term_to_string_2(BrowserDb, plain_term(Univ),
        MaxSize, CurSize, NewSize1, MaxDepth, CurDepth, Str),
    args_to_string_list(BrowserDb, Univs, MaxSize, NewSize1, NewSize,
        MaxDepth, CurDepth, RestStrs),
    Strs = [Str | RestStrs].

:- func bracket_string_list(list(string)) = string.

bracket_string_list(Args) = Str :-
    (
        Args = [],
        Str = ""
    ;
        Args = [_ | _],
        string.append_list(["(", comma_string_list(Args), ")"], Str)
    ).

:- func comma_string_list(list(string)) = string.

comma_string_list(Args) = Str :-
    (
        Args = [],
        Str = ""
    ;
        Args = [S],
        Str = S
    ;
        Args = [S1, S2 | Ss],
        Rest = comma_string_list([S2 | Ss]),
        string.append_list([S1, ", ", Rest], Str)
    ).

:- pred browser_term_compress(browser_db::in, browser_term::in, string::out)
    is cc_multi.

browser_term_compress(BrowserDb, BrowserTerm, Str) :-
    functor_browser_term_cc(BrowserDb, BrowserTerm, Functor, Arity, IsFunc),
    ( if Arity = 0 then
        Str = Functor
    else
        int_to_string(Arity, ArityStr),
        (
            IsFunc = yes,
            append_list([Functor, "/", ArityStr, "+1"], Str)
        ;
            IsFunc = no,
            append_list([Functor, "/", ArityStr], Str)
        )
    ).

%---------------------------------------------------------------------------%

    % Print using the pretty printer from the standard library.
    % XXX Because the pretty printer doesn't support a combination
    % of both size and depth, we use the depth, except when depth is 0,
    % in which case we use the size.
    %
:- pred browser_term_to_string_pretty(S::in,
    browser_term::in, int::in, int::in,
    int::in, int::in, io::di, io::uo) is det
    <= stream.writer(S, string, io).

browser_term_to_string_pretty(S, Term, Width, Lines, Size, Depth, !IO) :-
    (
        Term = plain_term(Univ),
        Doc = format_univ(Univ)
    ;
        Term = synthetic_term(Functor, Args, MaybeReturn),
        Doc = synthetic_term_to_doc(Functor, Args, MaybeReturn)
    ),
    get_default_formatter_map(Formatters, !IO),

    ( if Depth > 0 then
        Limit = triangular(Depth)
    else
        Limit = linear(Size)
    ),

    promise_equivalent_solutions [!:IO] (
        write_doc_to_stream(S, include_details_cc, Formatters,
            Width, Lines, Limit, Doc, !IO)
    ).

%---------------------------------------------------------------------------%

    % Verbose printing. Tree layout with numbered branches.
    % Numbering makes it easier to change to subterms.
    %
:- pred browser_term_to_string_verbose(browser_db::in, browser_term::in,
    int::in, int::in, int::in, int::in, string::out) is cc_multi.

browser_term_to_string_verbose(BrowserDb, BrowserTerm, MaxSize, MaxDepth,
        X, Y, Str) :-
    CurSize = 0,
    CurDepth = 0,
    browser_term_to_string_verbose_2(BrowserDb, BrowserTerm,
        MaxSize, CurSize, _NewSize, MaxDepth, CurDepth, Frame),
    ClippedFrame = frame.clip(X-Y, Frame),
    unlines(ClippedFrame, Str).

:- pred browser_term_to_string_verbose_2(browser_db::in, browser_term::in,
    int::in, int::in, int::out, int::in, int::in, frame::out) is cc_multi.

browser_term_to_string_verbose_2(BrowserDb, BrowserTerm,
        MaxSize, CurSize, NewSize, MaxDepth, CurDepth, Frame) :-
    limited_deconstruct_browser_term_cc(BrowserDb, BrowserTerm, MaxSize,
        MaybeFunctorArityArgs, MaybeReturn),
    ( if
        CurSize < MaxSize,
        CurDepth < MaxDepth,
        MaybeFunctorArityArgs = yes({Functor, _Arity, Args0})
    then
        % XXX We should consider formatting function terms differently.
        (
            MaybeReturn = yes(Return),
            list.append(Args0, [Return], Args)
        ;
            MaybeReturn = no,
            Args = Args0
        ),
        CurSize1 = CurSize + 1,
        CurDepth1 = CurDepth + 1,
        ArgNum = 1,
        args_to_string_verbose_list(BrowserDb, Args, ArgNum,
            MaxSize, CurSize1, NewSize, MaxDepth, CurDepth1, ArgsFrame),
        Frame = frame.vglue([Functor], ArgsFrame)
    else
        browser_term_compress(BrowserDb, BrowserTerm, Line),
        Frame = [Line],
        NewSize = CurSize
    ).

:- pred args_to_string_verbose_list(browser_db::in, list(univ)::in,
    int::in, int::in, int::in, int::out, int::in, int::in, frame::out)
    is cc_multi.

args_to_string_verbose_list(_BrowserDb, [], _ArgNum,
        _MaxSize, CurSize, NewSize, _MaxDepth, _CurDepth, []) :-
    NewSize = CurSize.
args_to_string_verbose_list(BrowserDb, [Univ], ArgNum,
        MaxSize, CurSize, NewSize, MaxDepth, CurDepth, Frame) :-
    browser_term_to_string_verbose_2(BrowserDb, plain_term(Univ), MaxSize,
        CurSize, NewSize, MaxDepth, CurDepth, TreeFrame),
    % XXX: ArgNumS must have fixed length 2.
    string.int_to_string(ArgNum, ArgNumS),
    string.append_list([ArgNumS, "-"], LastBranchS),
    Frame = frame.hglue([LastBranchS], TreeFrame).
args_to_string_verbose_list(BrowserDb, [Univ1, Univ2 | Univs], ArgNum, MaxSize,
        CurSize, NewSize, MaxDepth, CurDepth, Frame) :-
    browser_term_to_string_verbose_2(BrowserDb, plain_term(Univ1),
        MaxSize, CurSize, NewSize1, MaxDepth, CurDepth, TreeFrame),
    ArgNum1 = ArgNum + 1,
    args_to_string_verbose_list(BrowserDb, [Univ2 | Univs], ArgNum1,
        MaxSize, NewSize1, NewSize2, MaxDepth, CurDepth, RestTreesFrame),
    NewSize = NewSize2,
    % XXX: ArgNumS must have fixed length 2.
    string.int_to_string(ArgNum, ArgNumS),
    string.append_list([ArgNumS, "-"], BranchFrameS),
    Height = frame.vsize(TreeFrame) - 1,
    list.duplicate(Height, "|", VBranchFrame),
    LeftFrame = frame.vglue([BranchFrameS], VBranchFrame),
    TopFrame = frame.hglue(LeftFrame, TreeFrame),
    Frame = frame.vglue(TopFrame, RestTreesFrame).

:- pred unlines(list(string)::in, string::out) is det.

unlines([], "").
unlines([Line | Lines], Str) :-
    string.append(Line, "\n", NLine),
    unlines(Lines, Strs),
    string.append(NLine, Strs, Str).

%---------------------------------------------------------------------------%
%
% Miscellaneous path handling.
%

:- type deref_result(T)
    --->    deref_result(T)
    ;       deref_error(list(down_dir), down_dir).

    % We assume a root-relative path. We assume Term is the entire term
    % passed into browse/3, not a subterm.
    %
:- pred deref_subterm(browser_term::in, list(down_dir)::in,
    deref_result(browser_term)::out) is cc_multi.

deref_subterm(BrowserTerm, Path, Result) :-
    (
        BrowserTerm = plain_term(Univ),
        deref_subterm_2(Univ, Path, [], SubResult),
        deref_result_univ_to_browser_term(SubResult, Result)
    ;
        BrowserTerm = synthetic_term(_Functor, Args, MaybeReturn),
        (
            Path = [],
            SubBrowserTerm = BrowserTerm,
            Result = deref_result(SubBrowserTerm)
        ;
            Path = [Step | PathTail],
            ( if
                (
                    Step = down_child_num(N),
                    ( if
                        N = list.length(Args) + 1,
                        MaybeReturn = yes(ReturnValue)
                    then
                        ArgUniv = ReturnValue
                    else
                        % The first argument of a non-array
                        % is numbered argument 1.
                        list.index1(Args, N, ArgUniv)
                    )
                ;
                    Step = down_child_name(Name),
                    string_is_return_value_alias(Name),
                    MaybeReturn = yes(ArgUniv)
                )
            then
                deref_subterm_2(ArgUniv, PathTail, [Step], SubResult),
                deref_result_univ_to_browser_term(SubResult, Result)
            else
                Result = deref_error([], Step)
            )
        )
    ).

string_is_return_value_alias("r").
string_is_return_value_alias("res").
string_is_return_value_alias("rv").
string_is_return_value_alias("result").
string_is_return_value_alias("return").
string_is_return_value_alias("ret").

:- pred deref_result_univ_to_browser_term(deref_result(univ)::in,
    deref_result(browser_term)::out) is det.

deref_result_univ_to_browser_term(SubResult, Result) :-
    (
        SubResult = deref_result(SubUniv),
        SubBrowserTerm = plain_term(SubUniv),
        Result = deref_result(SubBrowserTerm)
    ;
        SubResult = deref_error(OKPath, ErrorDir),
        Result = deref_error(OKPath, ErrorDir)
    ).

:- pred deref_subterm_2(univ::in, list(down_dir)::in, list(down_dir)::in,
    deref_result(univ)::out) is cc_multi.

deref_subterm_2(Univ, Path, RevPath0, Result) :-
    (
        Path = [],
        Result = deref_result(Univ)
    ;
        Path = [Dir | Dirs],
        (
            Dir = down_child_num(N),
            ( if
                TypeCtor = type_ctor(univ_type(Univ)),
                type_ctor_name(TypeCtor) = "array",
                type_ctor_module_name(TypeCtor) = "array"
            then
                % The first element of an array is at index zero.
                arg_cc(univ_value(Univ), N, MaybeValue)
            else
                % The first argument of a non-array is numbered argument 1
                % by the user but argument 0 by deconstruct.argument.
                arg_cc(univ_value(Univ), N - 1, MaybeValue)
            )
        ;
            Dir = down_child_name(Name),
            named_arg_cc(univ_value(Univ), Name, MaybeValue)
        ),
        (
            MaybeValue = arg(Value),
            ArgN = univ(Value),
            deref_subterm_2(ArgN, Dirs, [Dir | RevPath0], Result)
        ;
            MaybeValue = no_arg,
            Result = deref_error(list.reverse(RevPath0), Dir)
        )
    ).

%---------------------------------------------------------------------------%

:- pred get_path(browser_info::in, path::out) is det.

get_path(Info, root_rel(UpDownDirs)) :-
    UpDownDirs = down_to_up_down_dirs(Info ^ bri_dirs).

:- pred set_path(path::in, browser_info::in, browser_info::out) is det.

set_path(NewPath, !Info) :-
    Dirs0 = !.Info ^ bri_dirs,
    change_dir(Dirs0, NewPath, Dirs),
    !Info ^ bri_dirs := Dirs.

:- pred change_dir(list(down_dir)::in, path::in, list(down_dir)::out) is det.

change_dir(PwdDirs, Path, RootRelDirs) :-
    (
        Path = root_rel(Dirs),
        NewDirs = Dirs
    ;
        Path = dot_rel(Dirs),
        NewDirs = down_to_up_down_dirs(PwdDirs) ++ Dirs
    ),
    simplify_dirs(NewDirs, RootRelDirs).

:- pred set_term(univ::in, browser_info::in, browser_info::out) is det.

set_term(Term, Info0, Info) :-
    set_browser_term(plain_term(Term), Info0, Info1),
    % Display from the root term.
    % This avoid errors due to dereferencing non-existent subterms.
    set_path(root_rel([]), Info1, Info).

:- pred set_browser_term(browser_term::in, browser_info::in, browser_info::out)
    is det.

set_browser_term(BrowserTerm, !Info) :-
    !Info ^ bri_term := BrowserTerm.

%---------------------------------------------------------------------------%
%
% Display predicates.
%

:- pred show_settings(debugger::in, browser_info::in,
    io::di, io::uo) is det.

show_settings(Debugger, Info, !IO) :-
    show_settings_caller(Debugger, Info, browse, "Browser", !IO),
    show_settings_caller(Debugger, Info, print, "Print", !IO),
    show_settings_caller(Debugger, Info, print_all, "Printall", !IO),

    write_string_debugger(Debugger, "Current path is: ", !IO),
    write_down_path(Debugger, Info ^ bri_dirs, !IO),
    nl_debugger(Debugger, !IO),

    write_string_debugger(Debugger,
        "Number of I/O actions printed is: ", !IO),
    write_int_debugger(Debugger,
        get_num_printed_io_actions(Info ^ bri_state), !IO),
    nl_debugger(Debugger, !IO).

:- pred show_settings_caller(debugger::in, browser_info::in,
    browse_caller_type::in, string::in,
    io::di, io::uo) is det.

show_settings_caller(Debugger, Info, Caller, CallerName, !IO) :-
    browser_info.get_format(Info, Caller, no, Format),
    write_string_debugger(Debugger, CallerName ++ " default format: ", !IO),
    print_format_debugger(Debugger, Format, !IO),
    nl_debugger(Debugger, !IO),

    write_string_debugger(Debugger, pad_right("", ' ', row_name_len), !IO),
    write_string_debugger(Debugger, pad_right("depth", ' ', depth_len), !IO),
    write_string_debugger(Debugger, pad_right("size", ' ', size_len), !IO),
    write_string_debugger(Debugger, pad_right("x clip", ' ', width_len), !IO),
    write_string_debugger(Debugger, pad_right("y clip", ' ', lines_len), !IO),
    nl_debugger(Debugger, !IO),

    show_settings_caller_format(Debugger, Info, Caller, CallerName,
        flat, "flat", !IO),
    show_settings_caller_format(Debugger, Info, Caller, CallerName,
        verbose, "verbose", !IO),
    show_settings_caller_format(Debugger, Info, Caller, CallerName,
        pretty, "pretty", !IO),
    show_settings_caller_format(Debugger, Info, Caller, CallerName,
        raw_pretty, "raw_pretty", !IO),
    nl_debugger(Debugger, !IO).

:- pred show_settings_caller_format(debugger::in, browser_info::in,
    browse_caller_type::in, string::in, portray_format::in, string::in,
    io::di, io::uo) is det.

show_settings_caller_format(Debugger, Info, Caller, CallerName,
        Format, FormatName, !IO) :-
    browser_info.get_format_params(Info, Caller, Format, Params),
    write_string_debugger(Debugger,
        pad_right(CallerName ++ " " ++ FormatName ++ ":", ' ', row_name_len),
        !IO),
    write_string_debugger(Debugger,
        pad_right(" ", ' ', centering_len), !IO),
    write_string_debugger(Debugger,
        pad_right(int_to_string(Params ^ depth), ' ', depth_len), !IO),
    write_string_debugger(Debugger,
        pad_right(int_to_string(Params ^ size), ' ', size_len), !IO),
    write_string_debugger(Debugger,
        pad_right(int_to_string(Params ^ width), ' ', width_len), !IO),
    write_string_debugger(Debugger,
        pad_right(int_to_string(Params ^ lines), ' ', lines_len), !IO),
    nl_debugger(Debugger, !IO).

:- func row_name_len = int.
:- func centering_len = int.
:- func depth_len = int.
:- func size_len = int.
:- func width_len = int.
:- func lines_len = int.

row_name_len  = 30.
centering_len =  3.
depth_len     = 10.
size_len      = 10.
width_len     = 10.
lines_len     = 10.

:- pred string_to_path(string::in, path::out) is semidet.

string_to_path(Str, Path) :-
    string.to_char_list(Str, Cs),
    chars_to_path(Cs, Path).

:- pred chars_to_path(list(char)::in, path::out) is semidet.

chars_to_path([C | Cs], Path) :-
    ( if C = ('/') then
        Path = root_rel(Dirs),
        chars_to_dirs(Cs, Dirs)
    else
        Path = dot_rel(Dirs),
        chars_to_dirs([C | Cs], Dirs)
    ).

:- pred chars_to_dirs(list(char)::in, list(up_down_dir)::out) is semidet.

chars_to_dirs(Cs, Dirs) :-
    split_dirs(Cs, Names),
    names_to_dirs(Names, Dirs).

:- pred names_to_dirs(list(string)::in, list(up_down_dir)::out) is semidet.

names_to_dirs([], []).
names_to_dirs([Name | Names], Dirs) :-
    ( if Name = ".." then
        Dirs = [updown_parent | RestDirs],
        names_to_dirs(Names, RestDirs)
    else if Name = "." then
        names_to_dirs(Names, Dirs)
    else if string.to_int(Name, Num) then
        Dirs = [updown_child_num(Num) | RestDirs],
        names_to_dirs(Names, RestDirs)
    else
        Dirs = [updown_child_name(Name) | RestDirs],
        names_to_dirs(Names, RestDirs)
    ).

:- pred split_dirs(list(char)::in, list(string)::out) is det.

split_dirs(Cs, Names) :-
    takewhile(not_slash, Cs, NameCs, Rest),
    string.from_char_list(NameCs, Name),
    (
        NameCs = [],
        Names = []
    ;
        NameCs = [_ | _],
        (
            Rest = [],
            Names = [Name]
        ;
            Rest = [_Slash | RestCs],
            split_dirs(RestCs, RestNames),
            Names = [Name | RestNames]
        )
    ).

:- pred not_slash(char::in) is semidet.

not_slash(C) :-
    C \= ('/').

simplify_dirs(Dirs, SimpleDirs) :-
    list.reverse(Dirs, RevDirs),
    simplify_rev_dirs(RevDirs, 0, [], SimpleDirs).

    % simplify_rev_dirs(RevUpDownDirs, ToDelete, !DownDirs):
    %
    % Assumes a reverse list of directories and removes redundant `..'
    % entries by scanning from the bottom most directory to the top,
    % counting how many `..' occurred (!.ToDelete) and removing entries
    % accordingly. !DownDirs accumulates the simplified dirs processed so far
    % so we can be tail recursive.
    %
:- pred simplify_rev_dirs(list(up_down_dir)::in, int::in,
    list(down_dir)::in, list(down_dir)::out) is det.

simplify_rev_dirs([], _, !DownDirs).
simplify_rev_dirs([RevUpDownDir | RevUpDownDirs], !.ToDelete, !DownDirs) :-
    (
        RevUpDownDir = updown_parent,
        !:ToDelete = !.ToDelete + 1
    ;
        (
            RevUpDownDir = updown_child_num(ChildNum),
            DownDir = down_child_num(ChildNum)
        ;
            RevUpDownDir = updown_child_name(ChildName),
            DownDir = down_child_name(ChildName)
        ),
        ( if !.ToDelete > 0 then
            !:ToDelete = !.ToDelete - 1
        else
            !:DownDirs = [DownDir | !.DownDirs]
        )
    ),
    simplify_rev_dirs(RevUpDownDirs, !.ToDelete, !DownDirs).

:- func down_dir_to_string(down_dir) = string.

down_dir_to_string(down_child_num(Num)) = int_to_string(Num).
down_dir_to_string(down_child_name(Name)) = Name.

:- func down_dirs_to_string(list(down_dir)) = string.

down_dirs_to_string([]) = "".
down_dirs_to_string([Dir | Dirs]) = DirStr :-
    (
        Dirs = [],
        DirStr = down_dir_to_string(Dir)
    ;
        Dirs = [_ | _],
        DirStr = down_dir_to_string(Dir) ++ "/" ++ down_dirs_to_string(Dirs)
    ).

%---------------------------------------------------------------------------%

:- pred write_term_mode_debugger(debugger::in, maybe(browser_mode_func)::in,
    list(down_dir)::in, io::di, io::uo) is det.

write_term_mode_debugger(Debugger, MaybeModeFunc, Dirs, !IO) :-
    (
        MaybeModeFunc = yes(ModeFunc),
        Mode = ModeFunc(Dirs),
        ModeStr = browser_mode_to_string(Mode),
        write_string_debugger(Debugger, ModeStr ++ "\n", !IO)
    ;
        MaybeModeFunc = no,
        write_string_debugger(Debugger,
            "Mode information not available.\n", !IO)
    ).

:- func browser_mode_to_string(browser_term_mode) = string.

browser_mode_to_string(input) = "Input".
browser_mode_to_string(output) = "Output".
browser_mode_to_string(not_applicable) = "Not Applicable".
browser_mode_to_string(unbound) = "Unbound".

%---------------------------------------------------------------------------%

    % These two functions are just like like pprint:to_doc, except their input
    % is not a natural term, but a synthetic term defined by a functor, a list
    % of arguments, and if the synthetic term is a function application, then
    % the result of that function application.
    %
    % The functor name has to be treated specially because '.'s therein
    % usually denote separators in a module qualified name; the
    % default pretty_printer formatter does not know this and will quote
    % such names.
    %
:- func synthetic_term_to_doc(string, list(univ), maybe(univ)) = doc.

synthetic_term_to_doc(Functor0, Args, MaybeReturn) = Doc :-
    ( if
        ( Functor0 = "!."
        ; Functor0 = "."
        ; Functor0 = ".."
        ; Functor0 = "=.."
        ; not string.contains_char(Functor0, ('.'))
        )
    then
        Doc0 = format_term(Functor0, Args)
    else
        FunctorDoc =
            qualified_functor_to_doc(string.split_at_char(('.'), Functor0)),
        (
            Args = [],
            Doc0 = FunctorDoc
        ;
            Args = [_ | _],
            Doc0 = indent([
                FunctorDoc, str("("),
                    format_list(Args, group([str(", "), nl])),
                str(")")
            ])
        )
    ),
    (
        MaybeReturn = no,
        Doc = Doc0
    ;
        MaybeReturn = yes(Return),
        Doc = docs([Doc0, str(" = "), format_arg(format_univ(Return))])
    ).

%-----------------------------------------------------------------------------%

:- func qualified_functor_to_doc(list(string)) = doc.

qualified_functor_to_doc([]) = str("").
qualified_functor_to_doc([Part]) = str(term_io.quoted_atom(Part)).
qualified_functor_to_doc([PartA, PartB | Parts]) =
    docs([str(term_io.quoted_atom(PartA)), str("."),
        qualified_functor_to_doc([PartB | Parts])]).

%---------------------------------------------------------------------------%
