%-----------------------------------------------------------------------------%
% Copyright (C) 1994-2005 The University of Melbourne.
% This file may only be copied under the terms of the GNU Library General
% Public License - see the file COPYING.LIB in the Mercury distribution.
%-----------------------------------------------------------------------------%
%
% File: int.m.
% Main authors: conway, fjh.
% Stability: medium.
%
% Predicates and functions for dealing with machine-size integer numbers.
%
% The behaviour of a computation for which overflow occurs is undefined.
% (In the current implementation, the predicates and functions in this
% module do not check for overflow, and the results you get are those
% delivered by the C compiler.  However, future implementations
% might check for overflow.)
%
%-----------------------------------------------------------------------------%

:- module int.

:- interface.

:- import_module array.
:- import_module enum.

:- instance enum(int).

	% less than
	%
:- pred int < int.
:- mode in  < in is semidet.

	% greater than
	%
:- pred int > int.
:- mode in  > in is semidet.

	% less than or equal
	%
:- pred int =< int.
:- mode in  =< in is semidet.

	% greater than or equal
	%
:- pred int >= int.
:- mode in >= in is semidet.

	% absolute value
	%
:- func int__abs(int) = int.
:- pred int__abs(int::in, int::out) is det.

	% maximum
	%
:- func int__max(int, int) = int.
:- pred int__max(int::in, int::in, int::out) is det.

	% minimum
	%
:- func int__min(int, int) = int.
:- pred int__min(int::in, int::in, int::out) is det.

	% conversion of integer to floating point
	% OBSOLETE: use float__float/1 instead.
	%
:- pragma obsolete(int.to_float/2).
:- pred int__to_float(int::in, float::out) is det.

	% exponentiation
	% int__pow(X, Y, Z): Z is X raised to the Yth power
	% Throws a `math__domain_error' exception if Y is negative.
	%
:- func int__pow(int, int) = int.
:- pred int__pow(int::in, int::in, int::out) is det.

	% base 2 logarithm
	% int__log2(X) = N is the least integer such that 2 to the
	% power N is greater than or equal to X.
	% Throws a `math__domain_error' exception if X is not positive.
	%
:- func int__log2(int) = int.
:- pred int__log2(int::in, int::out) is det.

	% addition
	%
:- func int + int = int.
:- mode in  + in  = uo  is det.
:- mode uo  + in  = in  is det.
:- mode in  + uo  = in  is det.

:- func int__plus(int, int) = int.

	% multiplication
	%
:- func int * int = int.
:- mode in  * in  = uo  is det.

:- func int__times(int, int) = int.

	% subtraction
	%
:- func int - int = int.
:- mode in  - in  = uo  is det.
:- mode uo  - in  = in  is det.
:- mode in  - uo  = in  is det.

:- func int__minus(int, int) = int.

	% flooring integer division
	% Truncates towards minus infinity, e.g. (-10) // 3 = (-4).
	%
	% Throws a `math__domain_error' exception if the right operand
	% is zero. See the comments at the top of math.m to find out how to
	% disable domain checks.
	%
:- func div(int::in, int::in) = (int::uo) is det.

	% truncating integer division
	% Truncates towards zero, e.g. (-10) // 3 = (-3).
	% `div' has nicer mathematical properties for negative operands,
	% but `//' is typically more efficient.
	%
	% Throws a `math__domain_error' exception if the right operand
	% is zero. See the comments at the top of math.m to find out how to
	% disable domain checks.
	%
:- func int // int = int.
:- mode in  // in  = uo  is det.

	% (/)/2 is a synonym for (//)/2 to bring Mercury into line with
	% the common convention for naming integer division.
	%
:- func int / int = int.
:- mode in  / in  = uo  is det.

	% unchecked_quotient(X, Y) is the same as X // Y, but the
	% behaviour is undefined if the right operand is zero.
	%
:- func unchecked_quotient(int::in, int::in) = (int::uo) is det.

	% modulus
	% X mod Y = X - (X div Y) * Y
	%
:- func int mod int = int.
:- mode in  mod in  = uo  is det.

	% remainder
	% X rem Y = X - (X // Y) * Y
	% `mod' has nicer mathematical properties for negative X,
	% but `rem' is typically more efficient.
	%
	% Throws a `math__domain_error' exception if the right operand
	% is zero. See the comments at the top of math.m to find out how to
	% disable domain checks.
	%
:- func int rem int = int.
:- mode in rem in = uo is det.

	% unchecked_rem(X, Y) is the same as X rem Y, but the
	% behaviour is undefined if the right operand is zero.
:- func unchecked_rem(int, int) = int.
:- mode unchecked_rem(in, in) = uo is det.

	% Left shift.
	% X << Y returns X "left shifted" by Y bits. 
	% To be precise, if Y is negative, the result is
	% X div (2^(-Y)), otherwise the result is X * (2^Y).
	%
:- func int << int = int.
:- mode in  << in  = uo  is det.

	% unchecked_left_shift(X, Y) is the same as X << Y
	% except that the behaviour is undefined if Y is negative,
	% or greater than or equal to the result of `int__bits_per_int/1'.
	% It will typically be implemented more efficiently than X << Y.
	%
:- func unchecked_left_shift(int::in, int::in) = (int::uo) is det.

	% Right shift.
	% X >> Y returns X "arithmetic right shifted" by Y bits.
	% To be precise, if Y is negative, the result is
	% X * (2^(-Y)), otherwise the result is X div (2^Y).
	%
:- func int >> int = int.
:- mode in  >> in  = uo  is det.

	% unchecked_right_shift(X, Y) is the same as X >> Y
	% except that the behaviour is undefined if Y is negative,
	% or greater than or equal to the result of `int__bits_per_int/1'.
	% It will typically be implemented more efficiently than X >> Y.
	%
:- func unchecked_right_shift(int::in, int::in) = (int::uo) is det.

	% even(X) is equivalent to (X mod 2 = 0).
	%
:- pred even(int::in) is semidet.

	% odd(X) is equivalent to (not even(X)), i.e. (X mod 2 = 1).
	%
:- pred odd(int::in) is semidet.

	% bitwise and
	%
:- func int /\ int = int.
:- mode in  /\ in  = uo  is det.

	% bitwise or
	%
:- func int \/ int = int.
:- mode in  \/ in  = uo  is det.

	% bitwise exclusive or (xor)
	%
:- func int__xor(int, int) = int.
:- mode int__xor(in, in) = uo is det.
:- mode int__xor(in, uo) = in is det.
:- mode int__xor(uo, in) = in is det.

	% bitwise complement
	%
:- func \ int = int.
:- mode \ in  = uo  is det.

	% unary plus
	%
:- func + int = int.
:- mode + in = uo is det.

	% unary minus
	%
:- func - int = int.
:- mode - in = uo is det.

	% is/2, for backwards compatibility with Prolog.
	%
:- pred is(T, T) is det.
:- mode is(uo, di) is det.
:- mode is(out, in) is det.

	% int__max_int is the maximum value of an int
	% on this machine.
	%
:- func int__max_int = int.
:- pred int__max_int(int::out) is det.

	% int__min_int is the minimum value of an int
	% on this machine.
	%
:- func int__min_int = int.
:- pred int__min_int(int::out) is det.

	% int__bits_per_int is the number of bits in an int
	% on this machine.
	%
:- func int__bits_per_int = int.
:- pred int__bits_per_int(int::out) is det.

	% fold_up(F, Low, High, !Acc) <=> list.foldl(F, Low .. High, !Acc)
	%
	% NOTE: fold_up/5 is undefined if High = int.max_int.
	%
:- pred int__fold_up(pred(int, T, T), int, int, T, T).
:- mode int__fold_up(pred(in, in, out) is det, in, in, in, out) is det.
:- mode int__fold_up(pred(in, di, uo) is det, in, in, di, uo) is det.
:- mode int__fold_up(pred(in, array_di, array_uo) is det, in, in,
	array_di, array_uo) is det.
:- mode int__fold_up(pred(in, in, out) is semidet, in, in, in, out)
	is semidet.
:- mode int__fold_up(pred(in, in, out) is nondet, in, in, in, out)
	is nondet.
:- mode int__fold_up(pred(in, di, uo) is cc_multi, in, in, di, uo)
	is cc_multi.
:- mode int__fold_up(pred(in, in, out) is cc_multi, in, in, in, out)
	is cc_multi.

	% fold_up(F, Low, High, Acc) <=> list.foldl(F, Low .. High, Acc)
	%
	% NOTE: fold_up/4 is undefined if High = int.max_int.
	%
:- func int__fold_up(func(int, T) = T, int, int, T) = T.

	% fold_down(F, Low, High, !Acc) <=> list.foldr(F, Low .. High, !Acc)
	%
	% NOTE: fold_down/5 is undefined if Low int.min_int.
	%
:- pred int__fold_down(pred(int, T, T), int, int, T, T).
:- mode int__fold_down(pred(in, in, out) is det, in, in, in, out) is det.
:- mode int__fold_down(pred(in, di, uo) is det, in, in, di, uo) is det.
:- mode int__fold_down(pred(in, array_di, array_uo) is det, in, in,
	array_di, array_uo) is det.
:- mode int__fold_down(pred(in, in, out) is semidet, in, in, in, out)
	is semidet.
:- mode int__fold_down(pred(in, in, out) is nondet, in, in, in, out)
	is nondet.
:- mode int__fold_down(pred(in, di, uo) is cc_multi, in, in, di, uo)
	is cc_multi.
:- mode int__fold_down(pred(in, in, out) is cc_multi, in, in, in, out)
	is cc_multi.
	
	% fold_down(F, Low, High, Acc) <=> list.foldr(F, Low .. High, Acc)
	%
	% NOTE: fold_down/4 is undefined if Low = int.min_int.
	%
:- func int__fold_down(func(int, T) = T, int, int, T) = T.

	% fold_up2(F, Low, High, !Acc1, Acc2) <=>
	% 	list.foldl2(F, Low .. High, !Acc1, !Acc2)
	%
	% NOTE: fold_up2/7 is undefined if High = int.max_int. 
	%
:- pred int__fold_up2(pred(int, T, T, U, U), int, int, T, T, U, U).
:- mode int__fold_up2(pred(in, in, out, in, out) is det, in, in, in, out,
	in, out) is det.
:- mode int__fold_up2(pred(in, in, out, in, out) is semidet, in, in, 
	in, out, in, out) is semidet.
:- mode int__fold_up2(pred(in, in, out, in, out) is nondet, in, in,
	in, out, in, out) is nondet.
:- mode int__fold_up2(pred(in, in, out, di, uo) is det, in, in, in, out,
	di, uo) is det.
:- mode int__fold_up2(pred(in, di, uo, di, uo) is det, in, in, di, uo,
	di, uo) is det.

	% fold_down2(F, Low, High, !Acc1, !Acc2) <=>
	% 	list.foldr2(F, Low .. High, !Acc1, Acc2).
	%
	% NOTE: fold_down2/7 is undefined if Low = int.min_int.
	%
:- pred int__fold_down2(pred(int, T, T, U, U), int, int, T, T, U, U).
:- mode int__fold_down2(pred(in, in, out, in, out) is det, in, in, in, out,
	in, out) is det.
:- mode int__fold_down2(pred(in, in, out, in, out) is semidet, in, in,
	in, out, in, out) is semidet.
:- mode int__fold_down2(pred(in, in, out, in, out) is nondet, in, in,
	in, out, in, out) is nondet.
:- mode int__fold_down2(pred(in, in, out, di, uo) is det, in, in, in, out,
	di, uo) is det.
:- mode int__fold_down2(pred(in, di, uo, di, uo) is det, in, in, di, uo,
	di, uo) is det.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.
:- interface.

	% Everything below here will not appear in the
	% Mercury Library Reference Manual.

%-----------------------------------------------------------------------------%

	% commutivity and associativity of +
:- promise all [A, B, C] 	( C = B + A <=> C = A + B ).
:- promise all [A, B, C, ABC]	( ABC = (A + B) + C <=> ABC = A + (B + C) ).

	% commutivity and associativity of *
:- promise all [A, B, C] 	( C = B * A <=> C = A * B ).
:- promise all [A, B, C, ABC]	( ABC = (A * B) * C <=> ABC = A * (B * C) ).

%-----------------------------------------------------------------------------%

	% floor_to_multiple_of_bits_per_int(Int)
	%
	% Returns the largest multiple of bits_per_int which
	% is less than or equal to `Int'.
	%
	% Used by sparse_bitset.m. Makes it clearer to gcc that parts
	% of this operation can be optimized into shifts, without
	% turning up the optimization level.
:- func floor_to_multiple_of_bits_per_int(int) = int.

	% Used by floor_to_multiple_of_bits_per_int, placed
	% here to make sure they go in the `.opt' file.

	% int__quot_bits_per_int(X) = X // bits_per_int.		
:- func int__quot_bits_per_int(int) = int.

	% int__times_bits_per_int(X) = X * bits_per_int.		
:- func int__times_bits_per_int(int) = int.

	% Used by bitmap.m.  Like the ones above, the purpose of
	% defining this in C is to make it clearer to gcc that
	% this can be optimized.

	% int__rem_bits_per_int(X) = X `rem` bits_per_int.		
:- func int__rem_bits_per_int(int) = int.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%

:- implementation.

:- import_module exception.
:- import_module math.
:- import_module std_util.

:- instance enum(int) where [
	to_int(X) = X,
	from_int(X) = X
].

% Most of the arithmetic and comparison operators are recognized by
% the compiler as builtins, so we don't need to define them here.

X div Y = Div :-
	Trunc = X // Y,
	(
		( X >= 0, Y >= 0
		; X < 0, Y < 0
		; X rem Y = 0
		)
	->
		Div = Trunc
	;
		Div = Trunc - 1
	).

:- pragma inline('//'/2).
X // Y = Div :-
	(
		domain_checks,
		Y = 0
	->
		throw(math__domain_error("int.'//'"))
	;
		Div = unchecked_quotient(X, Y)
	).

:- pragma inline('/'/2).
X / Y = X // Y.

:- pragma inline(rem/2).
X rem Y = Rem :-
	(
		domain_checks,
		Y = 0
	->
		throw(math__domain_error("int.rem"))
	;
		Rem = unchecked_rem(X, Y)
	).

	% This code is included here rather than just calling the version
	% in math.m because we currently don't do transitive inter-module
	% inlining, so code which uses `//'/2 but doesn't import math.m
	% couldn't have the domain check optimized away.
:- pred domain_checks is semidet.
:- pragma inline(domain_checks/0).

:- pragma foreign_proc("C",
	domain_checks,
	[will_not_call_mercury, promise_pure, thread_safe],
"
#ifdef ML_OMIT_MATH_DOMAIN_CHECKS
	SUCCESS_INDICATOR = MR_FALSE;
#else
	SUCCESS_INDICATOR = MR_TRUE;
#endif
").

:- pragma foreign_proc("C#",
	domain_checks,
	[thread_safe, promise_pure],
"
#if ML_OMIT_MATH_DOMAIN_CHECKS
	SUCCESS_INDICATOR = false;
#else
	SUCCESS_INDICATOR = true;
#endif
").
:- pragma foreign_proc("Java",
	domain_checks,
	[thread_safe, promise_pure],
"
	succeeded = true;
").

:- pragma inline(floor_to_multiple_of_bits_per_int/1).

floor_to_multiple_of_bits_per_int(X) = Floor :-
	Trunc = quot_bits_per_int(X),
	Floor0 = times_bits_per_int(Trunc),
	( Floor0 > X ->
		Floor = Floor0 - bits_per_int
	;
		Floor = Floor0
	).

X mod Y = X - (X div Y) * Y.

X << Y = Z :-
	int__bits_per_int(IntBits),
	( Y >= 0 ->
		( Y >= IntBits ->
			Z = 0
		;
			Z = unchecked_left_shift(X, Y)
		)
	;
		( Y =< -IntBits ->
			Z = (if X >= 0 then 0 else -1)
		;
			Z = unchecked_right_shift(X, -Y)
		)
	).

	% Note: this assumes two's complement arithmetic.
	% tests/hard_coded/shift_test.m will fail if this is not the case.
X >> Y = Z :-
	int__bits_per_int(IntBits),
	( Y >= 0 ->
		( Y >= IntBits ->
			Z = (if X >= 0 then 0 else -1)
		;
			Z = unchecked_right_shift(X, Y)
		)
	;
		( Y =< -IntBits ->
			Z = 0
		;
			Z = unchecked_left_shift(X, -Y)
		)
	).

:- pragma inline(even/1).
even(X):-
	(X /\ 1) = 0.

:- pragma inline(odd/1).
odd(X):-
	(X /\ 1) \= 0.

int__abs(Num) = Abs :-
	int__abs(Num, Abs).

int__abs(Num, Abs) :-
	( Num < 0 ->
		Abs = 0 - Num
	;
		Abs = Num
	).

int__max(X, Y) = Max :-
	int__max(X, Y, Max).

int__max(X, Y, Max) :-
	( X > Y ->
		Max = X
	;
		Max = Y
	).

int__min(X, Y) = Min :-
	int__min(X, Y, Min).

int__min(X, Y, Min) :-
	( X < Y ->
		Min = X
	;
		Min = Y
	).

int__pow(Base, Exp) = Result :-
	int__pow(Base, Exp, Result).

int__pow(Base, Exp, Result) :-
	( domain_checks, Exp < 0 ->
		throw(math__domain_error("int.pow"))
	;
		Result = int__multiply_by_pow(1, Base, Exp)
	).

:- func int__multiply_by_pow(int, int, int) = int.
	% Returns Scale0 * (Base ** Exp).
	% Requires that Exp >= 0.
int__multiply_by_pow(Scale0, Base, Exp) = Result :-
	( Exp = 0 ->
		Result = Scale0
	;
		( odd(Exp) ->
			Scale1 = Scale0 * Base
		;
			Scale1 = Scale0
		),
		Result = int__multiply_by_pow(Scale1, Base * Base, Exp div 2)
	).

int__log2(X) = N :-
	int__log2(X, N).

int__log2(X, N) :-
	( domain_checks, X =< 0 ->
		throw(math__domain_error("int__log2"))
	;
		int__log2_2(X, 0, N)
	).

:- pred int__log2_2(int, int, int).
:- mode int__log2_2(in, in, out) is det.

int__log2_2(X, N0, N) :-
	( X = 1 ->
		N = N0
	;
		X1 = X + 1,
		X2 = X1 // 2,
		N1 = N0 + 1,
		int__log2_2(X2, N1, N)
	).

%-----------------------------------------------------------------------------%

% is/2 is replaced with `=' in the parser, but the following is useful
% in case you should take the address of `is' or something weird like that.

is(X, X).

%-----------------------------------------------------------------------------%

/*
:- pred int__to_float(int, float) is det.
:- mode int__to_float(in, out) is det.
*/
:- pragma foreign_proc("C",
	int__to_float(IntVal::in, FloatVal::out),
	[will_not_call_mercury, promise_pure],
"
	FloatVal = IntVal;
").
:- pragma foreign_proc("C#",
	int__to_float(IntVal::in, FloatVal::out),
	[will_not_call_mercury, promise_pure],
"
	FloatVal = (double) IntVal;
").
:- pragma foreign_proc("Java",
	int__to_float(IntVal::in, FloatVal::out),
	[will_not_call_mercury, promise_pure],
"
	FloatVal = (double) IntVal;
").

%-----------------------------------------------------------------------------%

:- pragma foreign_decl("C", "
	#include <limits.h>

	#define ML_BITS_PER_INT		(sizeof(MR_Integer) * CHAR_BIT)
").

:- pragma foreign_proc("C",
	int__max_int(Max::out),
	[will_not_call_mercury, promise_pure, thread_safe],
"
	if (sizeof(MR_Integer) == sizeof(int)) {
		Max = INT_MAX;
	} else if (sizeof(MR_Integer) == sizeof(long)) {
		Max = LONG_MAX;
	} else {
		MR_fatal_error(""Unable to figure out max integer size"");
	}
").

:- pragma foreign_proc("C",
	int__min_int(Min::out),
	[will_not_call_mercury, promise_pure, thread_safe],
"
	if (sizeof(MR_Integer) == sizeof(int)) {
		Min = INT_MIN;
	} else if (sizeof(MR_Integer) == sizeof(long)) {
		Min = LONG_MIN;
	} else {
		MR_fatal_error(""Unable to figure out min integer size"");
	}
").

:- pragma foreign_proc("C",
	int__bits_per_int(Bits::out),
	[will_not_call_mercury, promise_pure, thread_safe],
"
	Bits = ML_BITS_PER_INT;
").

:- pragma foreign_proc("C",
	int__quot_bits_per_int(Int::in) = (Div::out),
	[will_not_call_mercury, promise_pure, thread_safe],
"
	Div = Int / ML_BITS_PER_INT;
").

:- pragma foreign_proc("C",
	int__times_bits_per_int(Int::in) = (Result::out),
	[will_not_call_mercury, promise_pure, thread_safe],
"
	Result = Int * ML_BITS_PER_INT;
").

:- pragma foreign_proc("C",
	int__rem_bits_per_int(Int::in) = (Rem::out),
	[will_not_call_mercury, promise_pure, thread_safe],
"
	Rem = Int % ML_BITS_PER_INT;
").

:- pragma foreign_proc("C#",
	int__max_int(Max::out),
	[will_not_call_mercury, promise_pure, thread_safe],
"
	Max = System.Int32.MaxValue;
").

:- pragma foreign_proc("C#",
	int__min_int(Min::out),
	[will_not_call_mercury, promise_pure, thread_safe],
"
	Min = System.Int32.MinValue;
").

:- pragma foreign_proc("C#",
	int__bits_per_int(Bits::out),
	[will_not_call_mercury, promise_pure, thread_safe],
"
	// we are using int32 in the compiler.
	// XXX would be better to avoid hard-coding this here.
	Bits = 32;
").

:- pragma foreign_proc("Java",
	int__max_int(Max::out),
	[will_not_call_mercury, promise_pure, thread_safe],
"
	Max = java.lang.Integer.MAX_VALUE;
").

:- pragma foreign_proc("Java",
	int__min_int(Min::out),
	[will_not_call_mercury, promise_pure, thread_safe],
"
	Min = java.lang.Integer.MIN_VALUE;
").

:- pragma foreign_proc("Java",
        int__bits_per_int(Bits::out),
	[will_not_call_mercury, promise_pure, thread_safe],
"
	// Java ints are 32 bits.
	Bits = 32;
").

int__quot_bits_per_int(Int::in) = (Result::out) :-
	Result = Int // int__bits_per_int.

int__times_bits_per_int(Int::in) = (Result::out) :-
	Result = Int * int__bits_per_int.

int__rem_bits_per_int(Int::in) = (Result::out) :-
	Result = Int rem int__bits_per_int.

%-----------------------------------------------------------------------------%
%-----------------------------------------------------------------------------%
% Ralph Becket <rwab1@cl.cam.ac.uk> 27/04/99
% 	Functional forms added.

int__plus(X, Y) = X + Y.

int__times(X, Y) = X * Y.

int__minus(X, Y) = X - Y.

int__max_int = X :-
	int__max_int(X).

int__min_int = X :-
	int__min_int(X).

int__bits_per_int = X :-
	int__bits_per_int(X).

%-----------------------------------------------------------------------------%

int__fold_up(P, Lo, Hi, !A) :-
	( if	Lo =< Hi
	  then	P(Lo, !A), int__fold_up(P, Lo + 1, Hi, !A)
	  else	true
	).		

int__fold_up(F, Lo, Hi, A) =
	( if Lo =< Hi then int__fold_up(F, Lo + 1, Hi, F(Lo, A)) else A ).

int__fold_up2(P, Lo, Hi, !A, !B) :-
	( if	Lo =< Hi
	  then	P(Lo, !A, !B), int__fold_up2(P, Lo + 1, Hi, !A, !B)
	  else	true
	).

%-----------------------------------------------------------------------------%

int__fold_down(P, Lo, Hi, !A) :-
	( if 	Lo =< Hi
	  then	P(Hi, !A), int__fold_down(P, Lo, Hi - 1, !A)
	  else	true
	).

int__fold_down(F, Lo, Hi, A) =
	( if Lo =< Hi then int__fold_down(F, Lo, Hi - 1, F(Hi, A)) else A ).

int__fold_down2(P, Lo, Hi, !A, !B) :-
	( if	Lo =< Hi
	  then	P(Hi, !A, !B), int__fold_down2(P, Lo, Hi - 1, !A, !B)
	  else	true
	).

%-----------------------------------------------------------------------------%
:- end_module int.
%-----------------------------------------------------------------------------%
