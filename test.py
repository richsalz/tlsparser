#! /usr/bin/env python

import os, StringIO, subprocess, sys

tests = (
  (
    "uint8 f; uint8 f;\n",
    "INFILE:1: error near ``;'': Duplicate symbol ``f'' found\n"
  ),
  (
    "",
    "INFILE:1: error near ``'': syntax error, unexpected $end\n"
  ),
  (
    "uint16 f<10..1>;\n",
    "INFILE:1: error near ``;'': ``f'' range 10 less than 1\n"
  ),
  (
    "uint16 f[0];\n",
    "INFILE:1: error near ``;'': ``f'' size (0) is not positive\n"
  ),
  (
    "uint16 f[2^33-1];\n",
    "INFILE:1: error near ``2^33-1'': Exponent out of range\n"
    "INFILE:1: error near ``;'': ``f'' size (0) is not positive\n"
  ),
  (
    "uint16 f[2^3-1];\n",
    "INFILE:1: error near ``2^3-1'': Bad exponent\n"
    "INFILE:1: error near ``;'': ``f'' size (0) is not positive\n"
  ),
  (
    "uint16 f[2^3-2];\n",
    "INFILE:1: error near ``2^3-2'': Bad exponent\n"
    "INFILE:1: error near ``;'': ``f'' size (0) is not positive\n"
  ),
  (
    "enum { a, a } b;\n",
    "INFILE:1: error near ``a'': Duplicate ``a'' in enum\n"
  ),
  (
    "enum { a(1), b } c;",
    "INFILE:1: error near ``}'': syntax error, unexpected '}', expecting '('\n"
  ),
  (
    "enum { a(1), b, } c;",
    "INFILE:1: error near ``,'': syntax error, unexpected ',', expecting '('\n"
  ),
  (
    "enum { a(20), b(20), (12) } d; ",
    "INFILE:1: error near ``;'': Value for ``a'' is too big (20 > 12)\n"
    "INFILE:1: error near ``;'': Enum ``b'' duplicates value 20\n"
    "INFILE:1: error near ``;'': Value for ``b'' is too big (20 > 12)\n"
  ),
  (
    '''extern f;
    uint32 g[f];
    uint32 gg[ff];''',
    "INFILE:3: error near ``;'': Unknown size reference ``ff''\n"
  ),
  (
    "select (f) { case a: ; } f;",
    "INFILE:1: error near ``{'': Unknown variant selector ``f''\n"
  ),
  (
    '''extern f;
    select (f) { case a: ; } g;''',
    ""
  ),
  (
    '''enum { true, false } bool;
    select (bool) {
      case a: case a: ;
    } g;''',
    "INFILE:3: error near ``:'': Duplicate case ``a''\n"
  ),
  (
    '''extern f; extern extensions;
    select (f) {
    case a: case b: case c: digitally-signed extensions;
    case d: ;
    } s;''',
    ""
  ),
  (
    '''extern f; extern extensions;
    select (f) {
    case a: case b: case c: digitally-signed extensions;
    case a: ;
    } s;''',
    "INFILE:5: error near ``;'': Duplicate case ``a'' in ``s''\n"
  ),
  (
    '''extern f; extern extensions;
    select (f) {
    case a: case b: case b: digitally-signed extensions;
    } s;''',
    "INFILE:3: error near ``:'': Duplicate case ``b''\n"
  ),
  (
    '''extern f; extern extensions;
    select (f) {
    case a: case b: case c: digitally-signed extensions ; uint8 spacer;
    } s;''',
    "INFILE:3: error near ``uint8'': syntax error, unexpected tUINT8, expecting tCASE or '}'\n"
  ),
  (
    '''extern f; extern extensions; extern d;
    select (f) {
    case a: case b: case c:
       digitally-signed extensions;
       d e;
    } s;''',
    ""
  ),
  (
    '''extern f; extern extensions;
    select (f) {
    case a: digitally-signed extensions ;
    case b: f;
    } s;''',
    ""
  ),
  (
    '''extern f; extern extensions;
    select (f) {
    case a: digitally-signed extensions ;
    case b: f field;
    } s;''',
    ""
  ),
  (
    '''extern f; extern extensions;
    select (f) {
    case c: f2 field;
    } s;''',
    "INFILE:4: error near ``}'': Unknown member type ``f2''\n"
  ),
  (
      "uint8 f; extern f;",
      ""
  ),
  (
    "extern f; uint8 f;",
    ""
  ),
  (
    "struct { uint8 f; uint8 f; } s;",
    "INFILE:1: error near ``;'': Duplicate item ``f'' in ``s''\n"
  ),
  (
    '''extern ZZ;
    struct { uint8 f; ZZ g; } s;''',
    ""
  ),
  (
    "struct { uint8 f; mytype g; } s;",
    "INFILE:1: error near ``;'': Unknown member type ``mytype''\n"
  ),
  (
    '''struct {
        uint8 size;
        opaque g[s.size];
       } s;''',
    "INFILE:3: error near ``;'': Unknown size reference ``s.size''\n"
    "INFILE:3: error near ``;'': Note: cannot resolve dotted items.\n"
  ),
  (
    '''struct {
        uint8 size;
       } s;
       opaque g[s.size];
       opaque h[s.size];''',
    "INFILE:4: error near ``;'': Unknown size reference ``s.size''\n"
    "INFILE:4: error near ``;'': Note: cannot resolve dotted items.\n"
    "INFILE:5: error near ``;'': Unknown size reference ``s.size''\n"
  ),
  (
    "struct { } empty;",
    ""
  ),
  (
    '''// comment
    uint8 foo;
    struct {foo bar;} baz;''',
    ""
  ),
  (
    "uint8 f; /* comment",
    "INFILE:1: error near ``'': EOF in comment\n"
  ),
  (
    "uint8 f; // /* comment",
    ""
  ),
  (
    '''extern Extension; extern extensions_present;
    uint8 ProtocolVersion; opaque Random[12]; opaque SessionID[2^8-1];
    struct {
          ProtocolVersion client_version;
          Random random;
          SessionID session_id;
          select (extensions_present) {
              case false:
                  ;
              case true:
                  Extension extensions<0..2^16-1>;
          };
      } ClientHello;''',
      ""
  ),
  (
    '''uint8 f; struct {} empty;
    select (f) {
    case false:
        select (f) {
            case false: ;
        }
    }''',
    "INFILE:4: error near ``select'': syntax error, unexpected tSELECT\n"
  ),
  (
    '''struct {
        struct {
            uint16 x[2];
        } n;
        uint32 x;
    } b;''',
    ""
  ),
  (
    '''struct { uint8 f[12]; } x;
    struct {
        struct {
            x nested[2];
        } n;
        uint32 x;
    } b;''',
    ""
  ),
  (
    '''struct {
        struct {
            foo nested[2];
        } n;
        uint32 x;
    } b;''',
    "INFILE:4: error near ``;'': Unknown member type ``foo''\n"
  ),
  (
    '''struct {
        select (b.x) {
            case foo: ;
        } n;
        uint32 x;
    } b;''',
    "INFILE:2: error near ``{'': Unknown variant selector ``b.x''\n"
    "INFILE:2: error near ``{'': Note: cannot resolve dotted items.\n"
  ),
)

infile = "test-in"
outfile = "test-out"
passed = 0
failed = 0
argv = ( "./parser", infile )
for test,expected in tests:
    open(infile, "w").write(test)
    subprocess.Popen(argv, stdout=open(outfile, "w")).wait()
    results = open(outfile).read()
    expected = expected.replace("INFILE", infile)
    if results == expected:
        passed += 1
    else:
        failed += 1
        print "---\nFail"
        print " - Test", passed + failed + 1, "\n", test, "\n"
        print " - Expected\n", expected, "\n"
        print " - Got\n", results, "\n"
        print "---"

os.unlink(infile)
os.unlink(outfile)
print "passed", passed, "failed", failed, "total", passed + failed
sys.exit(failed)
