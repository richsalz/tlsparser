%top{
/*
** RFC5246 Data definition language parser
** Rich Salz, rsalz@akamai.com, June 2013.
*/

#include <stdio.h>
#include "nodes.hpp"
#include "gram.hpp"

using namespace std;

//  Exports.
int lineno = 1;
}

ID      [_A-Za-z][_A-Za-z0-9]*
NUM     [0-9]+

%%

\.\.                 { return tDOTDOT; }
case                 { return tCASE; }
enum                 { return tENUM; }
extern               { return tEXTERN; }
select               { return tSELECT; }
struct               { return tSTRUCT; }
opaque               { return yylval.num = tOPAQUE; }
uint16               { return yylval.num = tUINT16; }
uint24               { return yylval.num = tUINT24; }
uint32               { return yylval.num = tUINT32; }
uint8                { return yylval.num = tUINT8; }
aead-ciphered        { return yylval.num = tAEAD_CIPHERED; }
block-ciphered       { return yylval.num = tBLOCK_CIPHERED; }
stream-ciphered      { return yylval.num = tSTREAM_CIPHERED; }
digitally-signed     { return yylval.num = tDIGITALLY_SIGNED; }
public-key-encrypted { return yylval.num = tPUBLIC_KEY_ENCRYPTED; }

[ \t]+               { ; }
\n                   { lineno++; }

$debug               { setyydebug(1); }
$nodebug             { setyydebug(0); }

{ID} {
    yylval.str = new string(yytext);
    return tID;
}
3des {
    yylval.str = new string(yytext);
    return tID;
}
{ID}(\.{ID})+ {
    /* Nested reference; foo.bar */
    yylval.str = new string(yytext);
    return tID;
}
{NUM} {
    yylval.num = atoi(yytext);
    return tNUMBER;
}
2^{NUM}-[1-9] {
    /* A hack to recognize 2^16-1 for example */
    int shift = atoi(yytext + 2);
    if (shift < 1 || shift > 32) {
        yylval.num = 0;
        vyyerror("Exponent out of range");
    }
    else if ((shift & 0x07) != 0) {
        yylval.num = 0;
        vyyerror("Bad exponent");
    }
    else {
        const char* cp = strchr(yytext, '-');
        int offset = atoi(++cp);
        yylval.num = (1 << shift) - offset;
    }
    return tNUMBER;
}

"/*" {
    for (int c = 0; ; ) {
        while ((c = yyinput()) != '*' && c != EOF)
            if (c == '\n')
                lineno++;
        if (c == '*') {
            while ((c = yyinput()) == '*')
                continue;
            if (c == '/')
                break;
        }
        if (c == EOF) {
            vyyerror("EOF in comment");
            yyterminate();
        }
    }
}
"//" {
    for (int c; (c = yyinput()) != '\n'; )
        if (c == EOF)
            yyterminate();
    unput('\n'); // Force a use
}

.                    { return *yytext; }

%%

int
yywrap()
{
    return 1;
}
