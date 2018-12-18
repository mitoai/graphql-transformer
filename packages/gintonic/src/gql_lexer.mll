{
    open Gql_parser
    exception LexError of string
}

let whitespace = [' ' '\t']

let name = ['_' 'a'-'z' 'A'-'Z'] ['_' 'a'-'z' 'A'-'Z' '0'-'9']* 

let lineterm = "\r\n" | ['\n' '\r']

let unicodeChar = ['a'-'f' 'A'-'F' '0'-'9']

let escapedUnicodeChar = '\\' 'u' unicodeChar unicodeChar unicodeChar unicodeChar


let negative_sign = '-'
let non_zero_digit = ['1'-'9']
let digit = ['0'-'9']

let exponent_indicator = ['e' 'E']

let fractional_part = '.' digit +

let sign = [ '-' '+' ]

let exponent_part = exponent_indicator sign? digit+

let integer_part = negative_sign? ('0' | (non_zero_digit digit*))

let float_value = integer_part (fractional_part|exponent_part|(fractional_part exponent_part))

let integer_value = integer_part

let comma = ','

rule read = 
    parse
    | whitespace    { read lexbuf }
    | lineterm      { read lexbuf }
    | comma         { read lexbuf }

    | ':'           { COLON }
    | '|'           { PIPE }
    | '@'           { AT }
    | '='           { EQUAL }
    | '&'           { AMPERSAND }
    | '$'           { DOLLAR }
    | '!'           { EXCLAMATION }

    | "..."         { SPREAD }

    | '{'           { L_BRACKET }
    | '}'           { R_BRACKET }
    | '['           { L_SQ_BRACKET }
    | ']'           { R_SQ_BRACKET }
    | '('           { L_PAREN }
    | ')'           { R_PAREN }

    | "true"        { TRUE }
    | "false"       { FALSE }
    | "null"        { NULL }

    | "transform"                       { TRANSFORM }
    | "on"                              { ON }
    | "fragment"                        { FRAGMENT }
    | "schema"                          { SCHEMA }
    | "type"                            { TYPE }
    | "enum"                            { ENUM }
    | "interface"                       { INTERFACE }
    | "implements"                      { IMPLEMENTS }
    | "directive"                       { DIRECTIVE }
    | "scalar"                          { SCALAR }
    | "input"                           { INPUT }
    | "union"                           { UNION }
    | "query"                           { OP_QUERY }
    | "mutation"                        { OP_MUTATION }
    | "subscription"                    { OP_SUBSCRIPTION }

    | "QUERY"                           { EDIR_QUERY }
    | "MUTATION"                        { EDIR_MUTATION }
    | "SUBSCRIPTION"                    { EDIR_SUBSCRIPTION }
    | "FIELD"                           { EDIR_FIELD }
    | "FRAGMENT_DEFINITION"             { EDIR_FRAGMENT_DEFINITION }
    | "FRAGMENT_SPREAD"                 { EDIR_FRAGMENT_SPREAD }
    | "INLINE_FRAGMENT"                 { EDIR_INLINE_FRAGMENT }

    | "SCHEMA"                          { TSDIR_SCHEMA }
    | "SCALAR"                          { TSDIR_SCALAR }
    | "OBJECT"                          { TSDIR_OBJECT }
    | "FIELD_DEFINITION"                { TSDIR_FIELD_DEFINITION }
    | "ARGUMENT_DEFINITION"             { TSDIR_ARGUMENT_DEFINITION }
    | "INTERFACE"                       { TSDIR_INTERFACE }
    | "UNION"                           { TSDIR_UNION }
    | "ENUM"                            { TSDIR_ENUM }
    | "ENUM_VALUE"                      { TSDIR_ENUM_VALUE }
    | "INPUT_OBJECT"                    { TSDIR_INPUT_OBJECT }
    | "INPUT_FIELD_DEFINITION"          { TSDIR_INPUT_FIELD_DEFINITION }

    | integer_value { INT (Lexing.lexeme lexbuf) }
    | float_value   { FLOAT (Lexing.lexeme lexbuf) }

    | "\"\"\""      { read_multiline_string "" lexbuf }
    | '"'           { read_string "" lexbuf }
    | '#'           { read_comment "" lexbuf }
    | name          { NAME (Lexing.lexeme lexbuf) }
    | _             { raise (LexError ("Illegal character: " ^ Lexing.lexeme lexbuf)) }
    | eof           { EOF }
and read_string s = 
    parse
    | '"'               { STRING s }
    | lineterm          { raise (LexError ("Illegal newline in string: " ^ (String.escaped (Lexing.lexeme lexbuf)))) }
    | '\\'              { raise (LexError ("Illegal character escape")) }
    | '\\' '/'          { read_string (s ^ (Lexing.lexeme lexbuf)) lexbuf }
    | '\\' '\\'         { read_string (s ^ (Lexing.lexeme lexbuf)) lexbuf }
    | '\\' 'b'          { read_string (s ^ (Lexing.lexeme lexbuf)) lexbuf }
    | '\\' 'f'          { read_string (s ^ (Lexing.lexeme lexbuf)) lexbuf }
    | '\\' 'n'          { read_string (s ^ (Lexing.lexeme lexbuf)) lexbuf }
    | '\\' 'r'          { read_string (s ^ (Lexing.lexeme lexbuf)) lexbuf }
    | '\\' 't'          { read_string (s ^ (Lexing.lexeme lexbuf)) lexbuf }
    | '\\' '"'          { read_string (s ^ (Lexing.lexeme lexbuf)) lexbuf }
    | escapedUnicodeChar { read_string (s ^ (Lexing.lexeme lexbuf)) lexbuf }
    | [^ '\\' '"' '\n' '\r'] +   { read_string (s ^ (Lexing.lexeme lexbuf)) lexbuf }
    | eof               { raise (LexError "String not terminated") }
and read_multiline_string s = 
    parse
    | "\"\"\""          { BLOCK_STRING s }
    | '\\' '"' '"' '"'  { read_multiline_string (s ^ Lexing.lexeme lexbuf) lexbuf }
    | '"'               { read_multiline_string (s ^ Lexing.lexeme lexbuf) lexbuf }
    | [^ '\\' '"' ] +   { read_multiline_string (s ^ Lexing.lexeme lexbuf) lexbuf }
    | eof               { raise (LexError "String not terminated") }
and read_comment s =
    parse
    | lineterm          { read lexbuf }
    | eof               { read lexbuf }
    | _                 { read_comment (s ^ Lexing.lexeme lexbuf) lexbuf }
