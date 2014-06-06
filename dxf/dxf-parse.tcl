#!/usr/bin/env tclkit8.6
#
source /data/mmti/src/mmtitcl/unix.tcl

array set dxfCodes {
	 1	text
	 2	name
	 5	id
	 6	linetype
	 7	textstyle
	 8	layer
	 9	varname

	10	x 11	x1 12 x2
	20	y 21	y1 22 x2

	40	dist
	41	e1
	42	e2
	50	a1
	51	a2

	62	color

	70	index
	999	comment
}

set dxfKeep { LTYPE LAYER ARC LINE CIRCLE }

proc dxf-parse { data { keep {} } } {
    set reply  {}
    set entity {}

    if { $keep eq "" } { set keep $::dxfKeep }

    foreach { code value } [split $data \n] {
	set code  [string trim $code]
	set value [string trim $value]

	if { $code == 100 } { continue }

	if { $code == 0 && $entity ne {} } {
	    if { $keep eq "-" || [lindex $entity 1] in $keep } {
		lappend reply [lrange $entity 1 end]
	    }
	    set entity {}
	}
	try { set code $::dxfCodes($code) } on error message {}
	lappend entity $code $value
    }

    return $reply
}

if { $argv0 eq [info script] } {
    if { [llength $argv] == 0 } {
	set argv /dev/stdin
    }

    puts [join [dxf-parse [cat [lindex $argv 0]] [lindex $argv 1]] \n]
}
