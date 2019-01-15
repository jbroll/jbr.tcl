
# http://wiki.tcl.tk/8612
#
proc polygon { xm ym rx ry args} {
    set DEG2RAD [expr {4*atan(1)*2/360}]

    array set V {-sides 0 -start 90 -extent 360} ;# Default values
	foreach {a value} $args {
	    if {! [info exists V($a)]} {error "unknown option $a"}
	    if {$value == {}} {error "value of \"$a\" missing"}
	    set V($a) $value
	}
    if {$V(-extent) == 0} {return {}}

	set n $V(-sides)
	if {$n == 0} {                              ;# 0 sides => circle
	    set n [expr {round(($rx+$ry)*0.5)}]
		if {$n < 2} {set n 4}
	}

    set dir [expr {$V(-extent) < 0 ? -1 : 1}]   ;# Extent can be negative
	if {abs($V(-extent)) > 360} {
	    set V(-extent) [expr {$dir * (abs($V(-extent)) % 360)}]
	}
    set step [expr {$dir * 360.0 / $n}]
	set numsteps [expr {1 + double($V(-extent)) / $step}]

	set xy {}

	for {set i 0} {$i < int($numsteps)} {incr i} {
	    set rad [expr {($V(-start) - $i * $step) * $DEG2RAD}]
		set x [expr {$rx*cos($rad)}]
		set y [expr {$ry*sin($rad)}]
		lappend xy [expr {$xm + $x}] [expr {$ym - $y}]
	}

    # Figure out where last segment should end
    if {$numsteps != int($numsteps)} {
	# Vecter V1 is last drawn vertext (x,y) from above
	# Vector V2 is the edge of the polygon
	set rad2 [expr {($V(-start) - int($numsteps) * $step) * $DEG2RAD}]
	    set x2 [expr {$rx*cos($rad2) - $x}]
	    set y2 [expr {$ry*sin($rad2) - $y}]

	    # Vector V3 is unit vector in direction we end at
	    set rad3 [expr {($V(-start) - $V(-extent)) * $DEG2RAD}]
	    set x3 [expr {cos($rad3)}]
	    set y3 [expr {sin($rad3)}]

	    # Find where V3 crosses V1+V2 => find j s.t.  V1 + kV2 = jV3
	    set j [expr {($x*$y2 - $x2*$y) / ($x3*$y2 - $x2*$y3)}]

	    lappend xy [expr {$xm + $j * $x3}] [expr {$ym - $j * $y3}]
    }
    return $xy
}
