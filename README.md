tlsparser
=========

A parser for the TLS data description language used in the IETF RFC's

This parses the "presentation language" from the SSL/TLS RFC's.

I started from the description in section 4 of RFC 5246.  I found what I
think are some errors in that section, based on uses of the language
in the rest of the RFC.  Unfortunately, I don't remember most of them.

The one group I do remember, has to do with the choices in a variant:
    - There can be more than one or two case tags.
    - There can be more than a simple "type" name in a choice, you can
      have multiple fields and crypto markers, etc.
    - There is no clean way to indicate "no content", which would be helpful

Running a diff between rfc5246.txt and rfc5246.original will show the
changes I had to make to get the samples to parse.

Things to do:
    - The doxygen stuff needs work.  Not sure if that's worth it.

Porting notes:
    - On Snow Leopard, comment out WEXTRA in Makefile (thanks, Russ).

--rich $alz
  rsalz@akamai.com
  June,July 2013
