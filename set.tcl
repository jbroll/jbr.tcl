
proc lintersect {a b} {
     foreach e $a {
 	set x($e) {}
     }
     set result {}
     foreach e $b {
 	if {[info exists x($e)]} {
 	    lappend result $e
 	}
     }
     return $result
 }

 proc lunion {a b} {
     foreach e $a {
 	set x($e) {}
     }
     foreach e $b {
 	if {![info exists x($e)]} {
 	    lappend a $e
 	}
     }
     return $a
 }

 proc ldifference {a b} {
     set result {}
     foreach e $a {
 	if {$e ni $b} {lappend result $e}
     }
     return $result
 }

 # Modified to combine the call by name and returned list of 3 lists API.
 #
 proc intersect3 {list1 list2 { inList1 {} } { inList2 {} } { inBoth {} } } {
    if { $inList1 ne {} } {
	upvar $inList1 in1
	upvar $inList2 in2
	upvar $inBoth  inB
    }

    set in1 [list]
    set in2 [list]
    set inB [list]

    set list1 [lsort $list1]
    set list2 [lsort $list2]

    # Shortcut for identical lists is faster
    if { $list1 == $list2 } {
	set inB $list1
    } else {
	set i 0
	    foreach element $list1 {
		if {[set p [lsearch [lrange $list2 $i end] $element]] == -1} {
		    lappend in1 $element
		} else {
		    if { $p > 0 } {
			set e [expr {$i + $p -1}]
			    foreach entry [lrange $list2 $i $e] {
				lappend in2 $entry
			    }
			incr i $p
		    }
		    incr i
			lappend inB $element
		}
	    }
	foreach entry [lrange $list2 $i end] {
	    lappend in2 $entry
	}
    }

    return [list $in1 $in2 $inB]
} ;# David Easton
