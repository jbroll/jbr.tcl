# Makefile for Hectospec Msg Library
#

#CC	= gcc -g -I.
CC	= cc -g -I.

DFLAGS  = -D_REENTRANT

PACKAGE = msg
TCLPACK = msg

LIBRARY = libmsg.a
PROGRAM =
SCRIPTS = msgclient msgtel msgget msgset msgcmd

INCFILE = msg.h
LIBS	= libmsg.a -lutil

TARGETS = $(LIBRARY) $(PROGRAM) tclIndex
TCLFILE = msg.tcl

all	: $(TARGETS)

# msgmulti.o

SOURCE	= msg.o msgclnt.o msgserv.o msgwait.o msgmulti.o ssplit.o domaincmp.o

libmsg.a: $(SOURCE)
	$(LIBSLINK)

include $(MMTIMAKEFILE)

$(SOURCE) : msg.h

install	::
	cat msgget > $(MMTIBIN)/msgget
	cat msgset > $(MMTIBIN)/msgset
	cat msgcmd > $(MMTIBIN)/msgcmd
	#cat msglog.tcl > $(MMTIBIN)/msglog
	chmod +x $(MMTIBIN)/msgget
	chmod +x $(MMTIBIN)/msgset
	chmod +x $(MMTIBIN)/msgcmd
	#chmod +x $(MMTIBIN)/msglog
