%-----------------------------------------------------------------------------%
%
% file: lexer.nl.
% main author: fjh.
%
% Lexical analysis.  This module defines the representation of tokens
% and exports predicates for reading in tokens from an input stream.
%
% See ISO Prolog 6.4.
%
%-----------------------------------------------------------------------------%

:- module lexer.
:- interface.
:- import_module char, string, int, float, list, std_util, io.

:- type	token
	--->	name(string)
	;	variable(string)
	;	integer(int)
	;	float(float)
	;	string(string)		% "...."
	;	open			% '('
	;	open_ct			% '(' without any preceding whitespace
	;	close			% ')'
	;	open_list		% '['
	;	close_list		% ']'
	;	open_curly		% '}'
	;	close_curly		% '{'
	;	ht_sep			% '|'
	;	comma			% ','
	;	end			% '.'
	;	junk(character)		% junk character in the input stream
	;	error(string)		% some other invalid token
	;	io_error(io__error)	% error reading from the input stream
	;	eof.			% end-of-file

:- type token_context == int.

:- type token_list == list(pair(token, token_context)).

:- pred lexer__get_token_list(token_list, io__state, io__state).
:- mode lexer__get_token_list(out, di, uo) is det.
%		Read a list of tokens from the current input stream.
%		Keep reading until either we encounter either an `end' token
%		(i.e. a full stop followed by whitespace) or the end-of-file.

%-----------------------------------------------------------------------------%

:- implementation.
:- import_module require.

	% We build the tokens up as lists of characters in reverse order.
	% When we get to the end of each token, we call
	% `lexer__rev_char_list_to_string/2' to convert that representation
	% into a string.

	% Comments of the form
	%	foo --> bar . baz
	% mean that we are parsing a `foo', and we've already scanned
	% past the `bar', so now we need to match with a `baz'.

lexer__get_token_list(Tokens) -->
	lexer__get_token(Token, Context),
	( { Token = eof } ->
		{ Tokens = [] }
	; { Token = end ; Token = error(_) } ->
		{ Tokens = [Token - Context] }
	;
		{ Tokens = [Token - Context | Tokens1] },
		lexer__get_token_list(Tokens1)
	).

:- pred lexer__get_token(token, token_context, io__state, io__state).
:- mode lexer__get_token(out, out, di, uo) is det.

lexer__get_token(Token, Context) -->
	lexer__get_token_1(Token),
	lexer__get_context(Context).

:- pred lexer__get_context(token_context, io__state, io__state).
:- mode lexer__get_context(out, di, uo) is det.

lexer__get_context(Context) -->
	io__get_line_number(Context).

%-----------------------------------------------------------------------------%

:- pred lexer__get_token_1(token, io__state, io__state).
:- mode lexer__get_token_1(out, di, uo) is det.

lexer__get_token_1(Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ Token = eof }
	; { Result = ok(Char) },
		( { Char = ' ' ; Char = '\t' ; Char = '\n' } ->
			lexer__get_token_2(Token)
		; { char__is_upper(Char) ; Char = '_' } ->
			lexer__get_variable([Char], Token)
		; { char__is_lower(Char) } ->
			lexer__get_name([Char], Token)
		; { Char = '0' } ->
			lexer__get_zero(Token)
		; { char__is_digit(Char) } ->
			lexer__get_number([Char], Token)
		; { lexer__special_token(Char, SpecialToken) } ->
			{ SpecialToken = open ->
				Token = open_ct
			;
				Token = SpecialToken
			}
		; { Char = '.' } ->
			lexer__get_dot(Token)
		; { Char = '%' } ->
			lexer__skip_to_eol(Token)
		; { Char = '"' ; Char = '\'' } ->
			lexer__get_quoted_name(Char, [], Token)
		; { Char = '/' } ->
			lexer__get_slash(Token)
		; { lexer__graphic_token_char(Char) } ->
			lexer__get_graphic([Char], Token)
		;
			{ Token = junk(Char) }
		)
	).

:- pred lexer__get_token_2(token, io__state, io__state).
:- mode lexer__get_token_2(out, di, uo) is det.

	% This is just like get_token_1, except that we have already
	% scanned past some whitespace, so '(' gets scanned as `open'
	% rather than `open_ct'.

lexer__get_token_2(Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ Token = eof }
	; { Result = ok(Char) },
		( { Char = ' ' ; Char = '\t' ; Char = '\n' } ->
			lexer__get_token_2(Token)
		; { char__is_upper(Char) ; Char = '_' } ->
			lexer__get_variable([Char], Token)
		; { char__is_lower(Char) } ->
			lexer__get_name([Char], Token)
		; { Char = '0' } ->
			lexer__get_zero(Token)
		; { char__is_digit(Char) } ->
			lexer__get_number([Char], Token)
		; { lexer__special_token(Char, SpecialToken) } ->
			{ Token = SpecialToken }
		; { Char = '.' } ->
			lexer__get_dot(Token)
		; { Char = '%' } ->
			lexer__skip_to_eol(Token)
		; { Char = '"' ; Char = '\'' } ->
			lexer__get_quoted_name(Char, [], Token)
		; { Char = '/' } ->
			lexer__get_slash(Token)
		; { lexer__graphic_token_char(Char) } ->
			lexer__get_graphic([Char], Token)
		;
			{ Token = junk(Char) }
		)
	).

%-----------------------------------------------------------------------------%

:- pred lexer__special_token(character, token).
:- mode lexer__special_token(in, out) is semidet.

lexer__special_token('(', open).	% May get converted to open_ct
lexer__special_token(')', close).
lexer__special_token('[', open_list).
lexer__special_token(']', close_list).
lexer__special_token('{', open_curly).
lexer__special_token('}', close_curly).
lexer__special_token('|', ht_sep).
lexer__special_token(',', comma).
lexer__special_token(';', name(";")).
lexer__special_token('!', name("!")).

:- pred lexer__graphic_token_char(character).
:- mode lexer__graphic_token_char(in) is semidet.

lexer__graphic_token_char('#').
lexer__graphic_token_char('$').
lexer__graphic_token_char('&').
lexer__graphic_token_char('*').
lexer__graphic_token_char('+').
lexer__graphic_token_char('-').
lexer__graphic_token_char('.').
lexer__graphic_token_char('/').
lexer__graphic_token_char(':').
lexer__graphic_token_char('<').
lexer__graphic_token_char('=').
lexer__graphic_token_char('>').
lexer__graphic_token_char('?').
lexer__graphic_token_char('@').
lexer__graphic_token_char('^').
lexer__graphic_token_char('~').
lexer__graphic_token_char('\\').

%-----------------------------------------------------------------------------%

:- pred lexer__get_dot(token, io__state, io__state).
:- mode lexer__get_dot(out, di, uo) is det.

lexer__get_dot(Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ Token = end }
	; { Result = ok(Char) },
		( { Char = ' ' ; Char = '\t' ; Char =  '\n' ; Char = '%' } ->
			io__putback_char(Char),
			{ Token = end }
		; { lexer__graphic_token_char(Char) } ->
			lexer__get_graphic([Char, '.'], Token)
		;
			{ Token = name(".") }
		)
	).

%-----------------------------------------------------------------------------%

	% comments

:- pred lexer__skip_to_eol(token, io__state, io__state).
:- mode lexer__skip_to_eol(out, di, uo) is det.

lexer__skip_to_eol(Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		% should be allow this?
		{ Token = error("unterminated '%' comment") }
	; { Result = ok(Char) },
		( { Char = '\n' } ->
			lexer__get_token_2(Token)
		;
			lexer__skip_to_eol(Token)
		)
	).

:- pred lexer__get_slash(token, io__state, io__state).
:- mode lexer__get_slash(out, di, uo) is det.

lexer__get_slash(Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		% should we allow this?
		{ Token = error("unterminated '%' comment") }
	; { Result = ok(Char) },
		( { Char = '*' } ->
			lexer__get_comment(Token)
		; { lexer__graphic_token_char(Char) } ->
			lexer__get_graphic([Char, '/'], Token)
		;
			{ Token = name("/") }
		)
	).

:- pred lexer__get_comment(token, io__state, io__state).
:- mode lexer__get_comment(out, di, uo) is det.

lexer__get_comment(Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ Token = error("unterminated '/*' comment") }
	; { Result = ok(Char) },
		( { Char = '*' } ->
			lexer__get_comment_2(Token)
		;
			lexer__get_comment(Token)
		)
	).

:- pred lexer__get_comment_2(token, io__state, io__state).
:- mode lexer__get_comment_2(out, di, uo) is det.

lexer__get_comment_2(Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ Token = error("unterminated '/*' comment") }
	; { Result = ok(Char) },
		( { Char = '/' } ->
			lexer__get_token_2(Token)
		; { Char = '*' } ->
			lexer__get_comment_2(Token)
		;
			lexer__get_comment(Token)
		)
	).

%-----------------------------------------------------------------------------%

	% quoted names and quoted strings

:- pred lexer__get_quoted_name(character, list(character), token,
				io__state, io__state).
:- mode lexer__get_quoted_name(in, in, out, di, uo) is det.

lexer__get_quoted_name(QuoteChar, Chars, Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ Token = error("unterminated quote") }
	; { Result = ok(Char) },
		( { Char = QuoteChar } ->
			lexer__get_quoted_name_quote(QuoteChar, Chars, Token)
		; { Char = '\\' } ->
			lexer__get_quoted_name_escape(QuoteChar, Chars, Token)
		;
			lexer__get_quoted_name(QuoteChar, [Char | Chars], Token)
		)
	).

:- pred lexer__get_quoted_name_quote(character, list(character), token,
				io__state, io__state).
:- mode lexer__get_quoted_name_quote(in, in, out, di, uo) is det.

lexer__get_quoted_name_quote(QuoteChar, Chars, Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ lexer__finish_quoted_name(QuoteChar, Chars, Token) }
	; { Result = ok(Char) },
		( { Char = QuoteChar } ->
			lexer__get_quoted_name(QuoteChar, [Char | Chars], Token)
		;
			io__putback_char(Char),
			{ lexer__finish_quoted_name(QuoteChar, Chars, Token) }
		)
	).

:- pred lexer__finish_quoted_name(character, list(character), token).
:- mode lexer__finish_quoted_name(in, in, out) is det.

lexer__finish_quoted_name(QuoteChar, Chars, Token) :-
	lexer__rev_char_list_to_string(Chars, String),
	( QuoteChar = '\'' ->
		Token = name(String)
	; QuoteChar = '"' ->
		Token = string(String)
	;
		error("lexer.nl: unknown quote character")
	).

:- pred lexer__get_quoted_name_escape(character, list(character), token,
					io__state, io__state).
:- mode lexer__get_quoted_name_escape(in, in, out, di, uo) is det.

lexer__get_quoted_name_escape(QuoteChar, Chars, Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ Token = error("unterminated quoted name") }
	; { Result = ok(Char0) }, !,
		( { Char0 = '\n' } ->
			lexer__get_quoted_name(QuoteChar, Chars, Token)
		; { lexer__escape_char(Char0, EscapedChar) } ->
			{ Chars1 = [EscapedChar | Chars] },
			lexer__get_quoted_name(QuoteChar, Chars1, Token)
		; { Char0 = 'x' } ->
			lexer__get_hex_escape(QuoteChar, Chars, [], Token)
		; { char__is_octal_digit(Char0) } ->
			lexer__get_octal_escape(QuoteChar, Chars, [], Token)
		;
			{ Token = error("invalid escape character") }
		)
	).

:- pred lexer__escape_char(character, character).
:- mode lexer__escape_char(in, out) is semidet.

lexer__escape_char('a', '\a').
lexer__escape_char('b', '\b').
lexer__escape_char('r', '\r').
lexer__escape_char('f', '\f').
lexer__escape_char('t', '\t').
lexer__escape_char('n', '\n').
lexer__escape_char('v', '\v').
lexer__escape_char('\\', '\\').
lexer__escape_char('\'', '\'').
lexer__escape_char('"', '"').
lexer__escape_char('`', '`').

:- pred lexer__get_hex_escape(character, list(character), list(character),
				token, io__state, io__state).
:- mode lexer__get_hex_escape(in, in, in, out, di, uo) is det.

lexer__get_hex_escape(QuoteChar, Chars, HexChars, Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ Token = error("unterminated quote") }
	; { Result = ok(Char0) }, !,
		( { char__is_hex_digit(Char0) } ->
			lexer__get_hex_escape(QuoteChar, [Char0 | Chars],
						HexChars, Token)
		; { Char0 = '\\' } ->
			lexer__finish_hex_escape(QuoteChar, Chars, HexChars,
				Token)
		;
			{ Token = error("unterminated hex escape") }
		)
	).

:- pred lexer__finish_hex_escape(character, list(character), list(character),
				token, io__state, io__state).
:- mode lexer__finish_hex_escape(in, in, in, out, di, uo) is det.

lexer__finish_hex_escape(QuoteChar, Chars, HexChars, Token) -->
	( { HexChars = [] } ->
		{ Token = error("empty hex escape") }
	;
		{ lexer__rev_char_list_to_string(HexChars, HexString) },
		(
			{ string__base_string_to_int(16, HexString, Int) },
			{ char_to_int(Char, Int) }
		->
			lexer__get_quoted_name(QuoteChar, [Char|Chars], Token) 
		;
			{ Token = error("invalid hex escape") }
		)
	).

:- pred lexer__get_octal_escape(character, list(character), list(character),
				token, io__state, io__state).
:- mode lexer__get_octal_escape(in, in, in, out, di, uo) is det.

lexer__get_octal_escape(QuoteChar, Chars, OctalChars, Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ Token = error("unterminated quote") }
	; { Result = ok(Char0) }, !,
		( { char__is_octal_digit(Char0) } ->
			lexer__get_octal_escape(QuoteChar, [Char0 | Chars],
						OctalChars, Token)
		; { Char0 = '\\' } ->
			lexer__finish_octal_escape(QuoteChar, Chars, OctalChars,
				Token)
		;
			{ Token = error("unterminated octal escape") }
		)
	).

:- pred lexer__finish_octal_escape(character, list(character), list(character),
				token, io__state, io__state).
:- mode lexer__finish_octal_escape(in, in, in, out, di, uo) is det.

lexer__finish_octal_escape(QuoteChar, Chars, OctalChars, Token) -->
	( { OctalChars = [] } ->
		{ Token = error("empty octal escape") }
	;
		{ lexer__rev_char_list_to_string(OctalChars, OctalString) },
		(
			{ string__base_string_to_int(8, OctalString, Int) },
			{ char_to_int(Char, Int) }
		->
			lexer__get_quoted_name(QuoteChar, [Char|Chars], Token) 
		;
			{ Token = error("invalid octal escape") }
		)
	).

%-----------------------------------------------------------------------------%

	% names and variables

:- pred lexer__get_name(list(character), token, io__state, io__state).
:- mode lexer__get_name(in, out, di, uo) is det.

lexer__get_name(Chars, Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ lexer__rev_char_list_to_string(Chars, Name) },
		{ Token = name(Name) }
	; { Result = ok(Char) },
		( { char__is_alnum_or_underscore(Char) } ->
			lexer__get_name([Char | Chars], Token)
		;
			io__putback_char(Char),
			{ lexer__rev_char_list_to_string(Chars, Name) },
			{ Token = name(Name) }
		)
	).

:- pred lexer__get_graphic(list(character), token, io__state, io__state).
:- mode lexer__get_graphic(in, out, di, uo) is det.

lexer__get_graphic(Chars, Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ lexer__rev_char_list_to_string(Chars, Name) },
		{ Token = name(Name) }
	; { Result = ok(Char) },
		( { lexer__graphic_token_char(Char) } ->
			lexer__get_graphic([Char | Chars], Token)
		;
			io__putback_char(Char),
			{ lexer__rev_char_list_to_string(Chars, Name) },
			{ Token = name(Name) }
		)
	).

:- pred lexer__get_variable(list(character), token, io__state, io__state).
:- mode lexer__get_variable(in, out, di, uo) is det.

lexer__get_variable(Chars, Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ lexer__rev_char_list_to_string(Chars, VariableName) },
		{ Token = variable(VariableName) }
	; { Result = ok(Char) },
		( { char__is_alnum_or_underscore(Char) } ->
			lexer__get_name([Char | Chars], Token)
		;
			io__putback_char(Char),
			{ lexer__rev_char_list_to_string(Chars, VariableName) },
			{ Token = variable(VariableName) }
		)
	).

%-----------------------------------------------------------------------------%

	% integer and float literals

:- pred lexer__get_zero(token, io__state, io__state).
:- mode lexer__get_zero(out, di, uo) is det.

lexer__get_zero(Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ Token = integer(0) }
	; { Result = ok(Char) },
		( { char__is_digit(Char) } ->
			lexer__get_number([Char], Token)
		; { Char = '\'' } ->
			lexer__get_char_code(Token)
		; { Char = 'b' } ->
			lexer__get_binary(Token)
		; { Char = 'o' } ->
			lexer__get_octal(Token)
		; { Char = 'x' } ->
			lexer__get_hex(Token)
		; { Char = '.' } ->
			lexer__get_float_decimals([Char], Token)
		; { Char = 'e' ; Char = 'E' } ->
			lexer__get_float_exponent([Char], Token)
		;
			io__putback_char(Char),
			{ Token = integer(0) }
		)
	).

:- pred lexer__get_char_code(token, io__state, io__state).
:- mode lexer__get_char_code(out, di, uo) is det.

lexer__get_char_code(Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ Token = error("unterminated char code constant") }
	; { Result = ok(Char) },
		{ char_to_int(Char, CharCode) },
		{ Token = integer(CharCode) }
	).

:- pred lexer__get_binary(token, io__state, io__state).
:- mode lexer__get_binary(out, di, uo) is det.

lexer__get_binary(Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ Token = error("unterminated binary constant") }
	; { Result = ok(Char) },
		( { char__is_binary_digit(Char) } ->
			lexer__get_binary_2([Char], Token)
		;
			io__putback_char(Char),
			{ Token = error("unterminated binary constant") }
		)
	).

:- pred lexer__get_binary_2(list(character), token, io__state, io__state).
:- mode lexer__get_binary_2(in, out, di, uo) is det.

lexer__get_binary_2(Chars, Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ lexer__rev_char_list_to_int(Chars, 2, Token) }
	; { Result = ok(Char) },
		( { char__is_binary_digit(Char) } ->
			lexer__get_binary_2([Char | Chars], Token)
		;
			io__putback_char(Char),
			{ lexer__rev_char_list_to_int(Chars, 2, Token) }
		)
	).

:- pred lexer__get_octal(token, io__state, io__state).
:- mode lexer__get_octal(out, di, uo) is det.

lexer__get_octal(Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ Token = error("unterminated octal constant") }
	; { Result = ok(Char) },
		( { char__is_octal_digit(Char) } ->
			lexer__get_octal_2([Char], Token)
		;
			io__putback_char(Char),
			{ Token = error("unterminated octal constant") }
		)
	).

:- pred lexer__get_octal_2(list(character), token, io__state, io__state).
:- mode lexer__get_octal_2(in, out, di, uo) is det.

lexer__get_octal_2(Chars, Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ lexer__rev_char_list_to_int(Chars, 8, Token) }
	; { Result = ok(Char) },
		( { char__is_octal_digit(Char) } ->
			lexer__get_octal_2([Char | Chars], Token)
		;
			io__putback_char(Char),
			{ lexer__rev_char_list_to_int(Chars, 8, Token) }
		)
	).

:- pred lexer__get_hex(token, io__state, io__state).
:- mode lexer__get_hex(out, di, uo) is det.

lexer__get_hex(Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ Token = error("unterminated hex constant") }
	; { Result = ok(Char) },
		( { char__is_hex_digit(Char) } ->
			lexer__get_hex_2([Char], Token)
		;
			io__putback_char(Char),
			{ Token = error("unterminated hex constant") }
		)
	).

:- pred lexer__get_hex_2(list(character), token, io__state, io__state).
:- mode lexer__get_hex_2(in, out, di, uo) is det.

lexer__get_hex_2(Chars, Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ lexer__rev_char_list_to_int(Chars, 16, Token) }
	; { Result = ok(Char) },
		( { char__is_hex_digit(Char) } ->
			lexer__get_hex_2([Char | Chars], Token)
		;
			io__putback_char(Char),
			{ lexer__rev_char_list_to_int(Chars, 16, Token) }
		)
	).

:- pred lexer__get_number(list(character), token, io__state, io__state).
:- mode lexer__get_number(in, out, di, uo) is det.

lexer__get_number(Chars, Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ lexer__rev_char_list_to_int(Chars, 10, Token) }
	; { Result = ok(Char) },
		( { char__is_digit(Char) } ->
			lexer__get_number([Char | Chars], Token)
		; { Char = '.' } ->
			lexer__get_float_decimals([Char | Chars], Token)
		; { Char = 'e' ; Char = 'E' } ->
			lexer__get_float_exponent([Char | Chars], Token)
		;
			io__putback_char(Char),
			{ lexer__rev_char_list_to_int(Chars, 10, Token) }
		)
	).

	% XXX the float literal syntax doesn't match ISO Prolog

:- pred lexer__get_float_decimals(list(character), token, io__state, io__state).
:- mode lexer__get_float_decimals(in, out, di, uo) is det.

	% float --> int '.' . {int} {exponent}

lexer__get_float_decimals(Chars, Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ lexer__rev_char_list_to_float(Chars, Token) }
	; { Result = ok(Char) },
		( { char__is_digit(Char) } ->
			lexer__get_float_decimals([Char | Chars], Token)
		; { Char = 'e' ; Char = 'E' } ->
			lexer__get_float_exponent([Char | Chars], Token)
		;
			io__putback_char(Char),
			{ lexer__rev_char_list_to_float(Chars, Token) }
		)
	).

:- pred lexer__get_float_exponent(list(character), token, io__state, io__state).
:- mode lexer__get_float_exponent(in, out, di, uo) is det.

	% float --> decimal exp . {sign} int

lexer__get_float_exponent(Chars, Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ lexer__rev_char_list_to_float(Chars, Token) }
	; { Result = ok(Char) },
		( { Char = '+' ; Char = '-' } ->
			lexer__get_float_exponent_2([Char | Chars], Token)
		; { char__is_digit(Char) } ->
			lexer__get_float_exponent_3([Char | Chars], Token)
		;
			io__putback_char(Char),
			{ Token =
			  error("unterminated exponent in float token") }
		)
	).

:- pred lexer__get_float_exponent_2(list(character), token,
				io__state, io__state).
:- mode lexer__get_float_exponent_2(in, out, di, uo) is det.

	% float --> decimal exp {sign} . int

lexer__get_float_exponent_2(Chars, Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ Token = error("unterminated exponent in float token") }
	; { Result = ok(Char) },
		( { char__is_digit(Char) } ->
			lexer__get_float_exponent_3([Char | Chars], Token)
		;
			io__putback_char(Char),
			{ Token =
			  error("unterminated exponent in float token") }
		)
	).

:- pred lexer__get_float_exponent_3(list(character), token,
					io__state, io__state).
:- mode lexer__get_float_exponent_3(in, out, di, uo) is det.

	% float --> decimal exp {sign} int .

lexer__get_float_exponent_3(Chars, Token) -->
	io__read_char(Result),
	( { Result = error(Error) }, !,
		{ Token = io_error(Error) }
	; { Result = eof }, !,
		{ lexer__rev_char_list_to_float(Chars, Token) }
	; { Result = ok(Char) },
		( { char__is_digit(Char) } ->
			lexer__get_float_exponent_3([Char | Chars], Token)
		;
			io__putback_char(Char),
			{ lexer__rev_char_list_to_float(Chars, Token) }
		)
	).

%-----------------------------------------------------------------------------%

	% Utility routines

:- pred lexer__rev_char_list_to_int(list(character), int, token).
:- mode lexer__rev_char_list_to_int(in, in, out) is det.

lexer__rev_char_list_to_int(RevChars, Base, Token) :-
	lexer__rev_char_list_to_string(RevChars, String),
	( string__base_string_to_int(Base, String, Int) ->
		Token = integer(Int)
	;
		Token = error("invalid integer token")
	).

:- pred lexer__rev_char_list_to_float(list(character), token).
:- mode lexer__rev_char_list_to_float(in, out) is det.

lexer__rev_char_list_to_float(RevChars, Token) :-
	lexer__rev_char_list_to_string(RevChars, String),
	( string__to_float(String, Float) ->
		Token = float(Float)
	;
		Token = error("invalid float token")
	).

:- pred lexer__rev_char_list_to_string(list(character), string).
:- mode lexer__rev_char_list_to_string(in, out) is det.

lexer__rev_char_list_to_string(RevChars, String) :-
	list__reverse(RevChars, Chars),
	string__from_char_list(Chars, String).

%-----------------------------------------------------------------------------%
