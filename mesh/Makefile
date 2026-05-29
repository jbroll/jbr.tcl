# Simple Makefile for jbr::mesh package

.PHONY: all clean install

CRITCL = /home/john/bin/critcl

all:
	$(CRITCL) -pkg mesh.tcl

install: all
	mkdir -p $(HOME)/lib/tcl8/lib
	rm -rf $(HOME)/lib/tcl8/lib/mesh
	cp -r lib/mesh $(HOME)/lib/tcl8/lib/mesh

clean:
	rm -rf lib
