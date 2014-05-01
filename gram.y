%{
/*
** RFC5246 Data definition language parser
** Rich Salz, rsalz@akamai.com, June 2013.
*/

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <unistd.h>
#include <stdarg.h>
#include "nodes.hpp"

using namespace std;

#define YYDEBUG 1

//  Internals
typedef pair<const Node*,bool> Entry;
typedef map<string, Entry> Symtab;

enum lookup_type {
    look_variant, look_size, look_member
};

static int depth = 0;
static int errors = 0;
static bool verbose = false;
static bool dupsok = false;
static const char* infile = "<stdin>";
static const char UNNAMED[] = "<unnamed>";
static Symtab table;
static const char version[] =
    "$Id: gram.y,v 1.21 2014/04/10 02:38:43 rsalz Exp $";

static void yyerror(const char* cp);
static void intern(const string* name, const Node* np, bool external=false);
static void lookup(const string& ref, lookup_type lt=look_size);
static void lookup(const NodeList& nlr);
static void checkdups(const string* name, const NodeList& nlr);
static void checkdups(const string* name, const ArmList& alr);
static void checkreflist(const ReferenceList& rlr);

%}

%union {
    int num;
    std::string* str;
    IDSet* idset;
    Node* node;
    NodeList* nodelist;
    Reference* ref;
    ReferenceList* reflist;
    Arm* arm;
    ArmList* armlist;
}

%token tCASE tDOTDOT tENUM tEXTERN tSTRUCT tSELECT
%token <num> tAEAD_CIPHERED tBLOCK_CIPHERED tSTREAM_CIPHERED
%token <num> tDIGITALLY_SIGNED tPUBLIC_KEY_ENCRYPTED
%token <num> tNUMBER tOPAQUE tUINT8 tUINT16 tUINT24 tUINT32
%token <str> tID

%type <num> primitive opt_size crypto opt_crypto strprolog
%type <str> opt_id varprolog
%type <idset> cases external_choices internal_choices
%type <node> statement simple enumerated struct variant
%type <nodelist> list
%type <ref> reference
%type <reflist> references
%type <arm> arm
%type <armlist> arms

%error-verbose

%start list

%%

list
    : statement {
        $$ = new NodeList;
        if ($1) 
            $$->push_back($1);
        if (verbose)
            printf("\nParsed ok\n---------\n");
    }
    | list statement {
        $$ = $1;
        if ($2)
            $$->push_back($2);
        if (verbose)
            printf("\nParsed ok\n---------\n");
    }
    ;

statement
    : simple
    | reference {
        $$ = $1;
    }
    | enumerated
    | struct
    | variant
    | error ';' {
        $$ = NULL;
    }
    ;

simple
    : primitive tID ';' {
        $$ = new Simple($2, $1);
        intern($2, $$);
    }
    | primitive tID '[' tNUMBER ']' ';' {
        if ($4 <= 0)
            vyyerror("``%s'' size is not positive, %d", $2->c_str(), $4);
        $$ = new Simple($2, $1);
        intern($2, $$);
    }
    | primitive tID '[' tID ']' ';' {
        lookup(*$4);
        $$ = new Simple($2, $1);
        intern($2, $$);
    }
    | primitive tID '<' tNUMBER tDOTDOT tNUMBER '>' ';' {
        if ($4 >= $6)
            vyyerror("``%s'' range %d less than %d", $2->c_str(), $4, $6);
        $$ = new Simple($2, $1);
        intern($2, $$);
    }
    | tEXTERN tID ';' {
        $$ = NULL;
        intern($2, $$, true);
    }
    ;

primitive
    : tOPAQUE
    | tUINT8
    | tUINT16
    | tUINT24
    | tUINT32
    ;

reference
    : tID tID ';' {
        $$ = new Reference($2, $1);
    }
    | tID tID '[' tNUMBER ']' ';' {
        if ($4 <= 0)
            vyyerror("``%s'' size is not positive, %d", $2->c_str(), $4);
        $$ = new Reference($2, $1);
    }
    | tID tID '[' tID ']' ';' {
        lookup(*$4);
        $$ = new Reference($2, $1);
    }
    | tID tID '<' tNUMBER tDOTDOT tNUMBER '>' ';' {
        if ($4 >= $6)
            vyyerror("``%s'' range %d less than %d", $2->c_str(), $4, $6);
        $$ = new Reference($2, $1);
    }
    | crypto tID ';' {
        $$ = new Reference(new string(UNNAMED), $2, $1);
    }
    | crypto tID tID ';' {
        $$ = new Reference($3, $2, $1);
    }
    ;

crypto
    : tAEAD_CIPHERED
    | tBLOCK_CIPHERED
    | tSTREAM_CIPHERED
    | tDIGITALLY_SIGNED
    | tPUBLIC_KEY_ENCRYPTED
    ;

enumerated
    : tENUM '{' internal_choices '}' tID ';' {
        $$ = new Compound($5, tENUM, $3);
        intern($5, $$);
    }
    | tENUM '{' external_choices opt_size '}' tID ';' {
        set<int> values;
        int size = $4;
        IDSet::iterator end($3->end());
        for (IDSet::iterator it($3->begin()); it != end; ++it) {
            if (values.find(it->second) != values.end())
                vyyerror("Enum ``%s'' duplicates value %d",
                    it->first.c_str(), it->second);
            else
                values.insert(it->second);
            if (size && it->second > size) {
                vyyerror("Value for ``%s'' is too big (%d > %d)",
                    it->first.c_str(), it->second, size);
            }
        }
        $$ = new Compound($6, tENUM, $3);
        intern($6, $$);
    }
    ;

internal_choices
    : tID {
        $$ = new IDSet(*$1);
    }
    | internal_choices ',' tID {
        if ($1->has(*$3))
            vyyerror("Duplicate ``%s'' in enum", $3->c_str());
        else
            $1->insert(*$3);
        $$ = $1;
    }
    ;

external_choices
    : tID '(' tNUMBER ')' {
        $$ = new IDSet(*$1, $3);
    }
    | external_choices ',' tID '(' tNUMBER ')' {
        if ($1->has(*$3))
            vyyerror("Duplicate ``%s'' in enum", $3->c_str());
        else
            $1->insert(*$3, $5);
        $$ = $1;
    }
    ;

opt_size
    : {
        $$ = 0;
    }
    | ',' '(' tNUMBER ')' {
        $$ = $3;
    }
    ;

struct
    : strprolog list '}' opt_id ';' {
        --depth;
        checkdups($4, *$2);
        if ($4 == NULL)
            $$ = NULL;
        else {
            $$ = new Compound($4, tSTRUCT, $2, $1);
            intern($4, $$);
            lookup(*$2);
        }
    }
    | strprolog '}' opt_id ';' {
        --depth;
        if ($3 == NULL)
            $$ = NULL;
        else {
            $$ = new Compound($3, tSTRUCT, new NodeList, $1);
            intern($3, $$);
        }
    }
    ;

strprolog
    : opt_crypto tSTRUCT '{' {
        ++depth;
        $$ = $1;
    }
    ;

opt_crypto
    : {
        $$ = 0;
    }
    | crypto
    ;

opt_id
    : {
        $$ = NULL;
    }
    | tID
    ;

variant
    : varprolog arms '}' opt_id ';' {
        --depth;
        checkdups($4, *$2);
        if ($4 == NULL)
            $$ = NULL;
        else {
            $$ = new Compound($4, tSELECT, $2);
            intern($4, $$);
        }
    }
    ;

varprolog
    : tSELECT '(' tID ')' '{' {
        lookup(*$3, look_variant);
        ++depth;
        $$ = $3;
    }
    ;

arms
    : arm {
        $$ = new ArmList;
        $$->push_back($1);
    }
    | arms arm {
        $$ = $1;
        $$->push_back($2);
    }
    ;

arm
    : cases tID ';' {
        ReferenceList* rlp = new ReferenceList;
        rlp->push_back(new Reference(new string(UNNAMED), $2));
        $$ = new Arm($1, rlp);
    }
    | cases references {
        checkreflist(*$2);
        $$ = new Arm($1, $2);
    }
    | cases ';' {
        $$ = new Arm($1, new ReferenceList);
    }
    ;

cases
    : tCASE tID ':' {
        $$ = new IDSet(*$2);
    }
    | cases tCASE tID ':' {
        if ($1->has(*$3))
            vyyerror("Duplicate case ``%s''", $3->c_str());
        else
            $1->insert(*$3);
        $$ = $1;
    }
    ;

references
    : reference {
        $$ = new ReferenceList;
        $$->push_back($1);
    }
    | references reference {
        $$ = $1;
        $$->push_back($2);
    }
    ;

%%

/// Set yydebug variable.
void
setyydebug(bool flag)
{
    yydebug = flag ? 1 : 0;
    printf("YYDEBUG set to %s\n", flag ? "ON" : "OFF");
}


/// Print an error message, bump error count.
static void
yyerror(const char* cp)
{
    printf("%s:%d: error near ``%s'': %s\n",
        infile, lineno, yytext, cp);
    ++errors;
}

/// Format an error message and report it.
void
vyyerror(const char* fmt, ...)
{
    char buff[2048];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buff, sizeof buff, fmt, ap);
    va_end(ap);
    yyerror(buff);
}

/// Add a data type (name) to the symbol table.
static void
intern(const string* name, const Node* np, bool external)
{
    // Only put items at top-level into the symbol table.
    if (depth)
        return;

    // Check for dups, but ignore if it's an extern declaration.
    if (!dupsok) {
        Symtab::iterator it(table.find(*name));
        if (it != table.end() && it->second.second == false) {
            if (!external)
                vyyerror("Duplicate symbol ``%s'' found", name->c_str());
            return;
        }
    }
    const string key(*name);
    table[key] = make_pair(np, external);
}

/// Check that every name in a NodeList has been defined.
static void
lookup(const NodeList& nlr)
{
    for (NodeList::const_iterator it(nlr.begin()); it != nlr.end(); ++it) {
        const Node* n = *it;
        if (dynamic_cast<const Simple*>(n) != NULL)
            continue;
        const Reference* r = dynamic_cast<const Reference*>(n);
        if (r)
            lookup(r->Ref(), look_member);
    }
}

/// Lookup a name and print an error if not already defined.
static void
lookup(const string& sr, lookup_type lt)
{
    if (table.find(sr) != table.end())
        return;

    switch (lt) {
    case look_variant:
        vyyerror("Unknown variant selector ``%s''", sr.c_str());
        break;
    case look_size:
        vyyerror("Unknown size reference ``%s''", sr.c_str());
        break;
    case look_member:
        vyyerror("Unknown member type ``%s''", sr.c_str());
        break;
    }

    if (sr.find('.') != string::npos) {
        // Work around a parser limitation.  We can't do
        //   struct {
        //     uint8 size;
        //     opaque data[foo.size]; <<Field within struct being defined.
        //   } foo;
        --errors;
        static bool warned = false;
        if (!warned) {
            vyyerror("Note: cannot resolve dotted items.");
            --errors;
            warned = true;
        }
        return;
    }
}

/// Check for duplicates in a NodeList
static void
checkdups(const string* name, const NodeList& nlr)
{
    const char* namestr = name ? name->c_str() : UNNAMED;
    set<string> names;
    for (NodeList::const_iterator it(nlr.begin()); it != nlr.end(); ++it) {
        const Node* n = *it;
        const string* s(n->Name());
        if (s == NULL || *s == UNNAMED)
            continue;
        if (names.find(*s) != names.end())
            vyyerror("Duplicate item ``%s'' in ``%s''", s->c_str(), namestr);
        else
            names.insert(*s);
    }
}

/// Check all the arms in a variant for duplicate values.
static void
checkdups(const string* name, const ArmList& alr)
{
    const char* namestr = name ? name->c_str() : UNNAMED;
    set<string> casenames;
    for (ArmList::const_iterator it(alr.begin()); it != alr.end(); ++it) {
        const Arm* a = *it;
        IDSet::iterator end(a->Cases().end());
        for (IDSet::iterator idit(a->Cases().begin()); idit != end; ++idit) {
            if (casenames.find(idit->first) != casenames.end())
                vyyerror("Duplicate case ``%s'' in ``%s''",
                    idit->first.c_str(), namestr);
            else
                casenames.insert(idit->first);
        }
    }
}

/// Check ReferenceList for duplicates and unknown names
static void
checkreflist(const ReferenceList& rlr)
{
    set<string> names;
    for (ReferenceList::const_iterator it(rlr.begin()); it != rlr.end(); ++it) {
        const Reference* r = *it;
        const string* s(r->Name());
        if (s && *s != UNNAMED) {
            if (names.find(*s) != names.end())
                vyyerror("Duplicate item ``%s'' in variant arm", s->c_str());
            else
                names.insert(*s);
        }
        lookup(r->Ref(), look_member);
    }
}

/// Print usage message and exit
static void
usage()
{
    printf("usage:\n"
        "  parser [-d][-n][-v] [input]\n"
        "where:\n"
        "  -d    Turn on yydebug\n"
        "  -n    Do not complain about duplicate names\n"
        "  -v    Verbose (message when parsed succesfully)\n"
        "  input Input file, defaults to stdin\n"
        );
    exit(1);
}

int
main(int ac, char *av[])
{
    int i;

    // Parse JCL.
    while ((i = getopt(ac, av, "dnv")) != EOF)
        switch (i) {
        default:
            usage();
        case 'd':
            setyydebug(true);
            break;
        case 'n':
            dupsok = true;
            break;
        case 'v':
            verbose = true;
            break;
        }
    ac -= optind;
    av += optind;

    // Open input.
    if (ac == 1) {
        infile = av[0];
        if (freopen(infile, "r", stdin)  == NULL) {
            perror(infile);
            return 1;
        }
    }
    else if (ac != 0)
        usage();

    yyparse();
    return errors;
}
