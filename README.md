tlsparser
=========

A parser for the TLS data description language used in the IETF RFC's

This parses the "presentation language" from the SSL/TLS RFC's.

I started from the description in section 4 of RFC 5246.  I found what I
think are some errors in that section, based on uses of the language
in the rest of the RFC.  Unfortunately, I don't remember most of them.

The one group I do remember, has to do with the choices in a variant:
- There can be more than one or two case tags.
- There can be more than a simple "type" name in a choice, you can have multiple fields and crypto markers, etc.
- There is no clean way to indicate "no content", which would be helpful

Running a diff between rfc5246.txt and rfc5246.original will show the
changes I had to make to get the samples to parse.

Things to do
------------

- The doxygen stuff needs work.  Not sure if that's worth it.

Porting notes
-------------

- Uses the GNU/FSF toolchain (bison, flex, make)
- On Snow Leopard, comment out WEXTRA in Makefile (thanks, Russ).


License
-------
   Copyright 2013, Rich Salz

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

> rich $alz<br/>
> rsalz@akamai.com<br/>
> June,July 2013

