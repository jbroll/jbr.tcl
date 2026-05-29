# Simple Makefile for jbr::mesh package

.PHONY: all clean install

CRITCL = /home/john/bin/critcl

all:
	$(CRITCL) -pkg mesh.tcl

install: all
	rm -rf ~/lib/mesh
	cp -r lib/mesh ~/lib/mesh

clean:
	rm -rf lib
