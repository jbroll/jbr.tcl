# Makefile for Hectospec Msg Library
#

DFLAGS  = -g
CC      = cc

LIBRARY = libmsg.a
PROGRAM = cclient cserver mserv mrecv

INCFILE = msg.h
LIBS	= ../libmsg.a /data/mmti/src/util/libutil.a

TARGETS = $(PROGRAM) 

all	: $(TARGETS)

SOURCE	= cclient.o cserver.o 

cclient	: cclient.o
	$(PROGLINK)

cserver	: cserver.o
	$(PROGLINK)

mserv	: mserv.o
	$(PROGLINK)

mrecv	: mrecv.o
	$(PROGLINK)

include $(MMTIMAKEFILE)



