#!/usr/bin/env tclkit8.6 
#
# unsource <file>
#
# unsource is a command line program to remove "source" statements by replacing them
# with the contents of the sourced file.  The program is used to create a single file
# that contains all the code related to a program, library or module.  Sometimes a
# source statement is used to read in parameters or data from the runtime environment.
# When this is the case the source statement can be annotated with "Not UnSourced" as
# a comment on the same line and the source statement will be left in the output.
#
proc K { x y } { set x }

proc unsource { file } {
   set i 1
   foreach line [split [K [read [set fp [open $file]]] [close $fp]] \n] {
       if { [regexp {^[ \t]*source ([^ ]*)} $line -> xfile]      \
        && ![regexp {Not UnSourced} $line]} {
           try { unsource $xfile 
           } on error msg {
               error "unsourcing $xfile in $file line $i: $msg"
           }

           continue
       }
       puts $line
       incr i
   }
}

if { [file tail [info script]] eq "unsource" } {
    unsource $argv
}
