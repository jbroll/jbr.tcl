#!/bin/sh
# \
exec wish "$0" "$@"

source ../msg.tcl

global x
global y
set x 273
set y 273

msg_client EXAMPLE


msg_subscribe EXAMPLE temp1 x
msg_subscribe EXAMPLE temp2 y

label .e -textvariable x
grid .e
label .e2 -textvariable y
grid .e2
button .quit -text "Quit Display"  -command {exit}
grid .quit

msg_subscribe EXAMPLE temp1 temp1

proc callme { args } {
	puts "CallMe $args"
}
#puts "Here: [msg_get EXAMPLE temp2 {} sync callme]"

