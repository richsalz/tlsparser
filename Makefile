## RFC5246 Data definition language parser
## Rich Salz, rsalz@akamai.com, June 2013.

DISTRO	= $(shell awk 'NR>2 { print $$1;}' <MANIFEST)
TARDIR	= tlsgrammar

WARN	= -Wall -Wextra -Werror -Wunused -Wwrite-strings \
	  -Wstrict-overflow=4 -Wmissing-include-dirs -Winit-self \
	  -Wcast-qual -Wformat -Wmissing-format-attribute -Wformat-nonliteral \
	  -Wformat-security -Wswitch-enum -Wshadow
WEXTRA	= -Wmissing-declarations -Wlogical-op
CFLAGS	= -g $(WARN) $(WEXTRA)
CXXFLAGS= $(CFLAGS)

all:	parser

.PHONY: tar
tar: $(TARDIR).tar

.PHONY: doxy
doxy:
	doxygen Doxyfile
test:	parser test.py
	python test.py
	@touch $@

$(TARDIR).tar: $(DISTRO)
	@rm -rf $(TARDIR) $@
	mkdir $(TARDIR)
	cp $(DISTRO) $(TARDIR)/.
	tar cf $@ $(TARDIR)
	rm -rf $(TARDIR)

parser: gram.o lex.o
	$(CXX) -o $@ gram.o lex.o
clean:
	rm -f parser gram.output gram.?pp gram.o lex.?pp lex.o test
	rm -rf $(TARDIR) $(TARDIR).tar doxy

gram.o: gram.cpp gram.hpp nodes.hpp
gram.cpp: gram.y
	bison -v --output=$@ $?
gram.hpp: gram.y
	bison --defines=$@ --output=/dev/null $?

lex.o: lex.cpp gram.hpp nodes.hpp
lex.cpp: lex.l
	flex --outfile=$@ $?
lex.hpp: lex.l
	flex --header-file=$@ --outfile=/dev/null $?
