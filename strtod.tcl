
proc sexagesimal { x { format %05.4f } } {
    if { $x < 0 } {
	set x [expr {-($x)}]
	    set sign "-"
    } else {
	set sign ""
    }

    set d [expr {int($x)}]
	set x [expr {($x - $d)*60.}]
	set m [expr {int($x)}]
	set s [expr {($x - $m)*60.}]

	return [format "%s%02d:%02d:$format" $sign $d $m $s]
}

proc tcl::mathfunc::sign { x } {
    if { $x < 0 } { return -1 }
    return 1
}

proc strtod { x } {
    set l [split $x :]

	if { [llength $l] == 3 } {
	    foreach { h m s } $l {}

	    scan $h %f h
	    scan $m %f m
	    scan $s %f s

	    set x [expr {sign($h) * (abs($h) + $m/60.0 + $s/3600.0)}]
	}

    return $x
}

