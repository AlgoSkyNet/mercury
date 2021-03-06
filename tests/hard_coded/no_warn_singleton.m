%---------------------------------------------------------------------------%
% vim: ts=4 sw=4 et ft=mercury
%---------------------------------------------------------------------------%
%
% A regression test to ensure that we don't get warnings about the variables
% _IO0 and _IO occuring more than once.

:- module no_warn_singleton.

:- interface.

:- import_module io.

:- pred main(io::di, io::uo) is det.

:- implementation.

main -->
    f(X),
    io__write_int(X),
    io__nl.

:- pred f(int::out, io::di, io::uo) is det.

:- pragma foreign_proc("C",
    f(X::out, _IO0::di, _IO::uo),
    [will_not_call_mercury, promise_pure],
"
    X = 5;
").

f(5) --> [].
