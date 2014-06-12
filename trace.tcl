
 proc traceproc-print { args } { puts $args }

 # Seed the excludes list with items that are annoying
 #
 set traceprocExclude [list ::tcl::clock::* msgcat::* ConvertLocale]

 proc traceproc-add   { patt proc op args } {
    lassign $proc type proc args body

    if { [string match $patt $proc] } {
	foreach excl $::traceprocExclude {
	    if { [string match $excl $proc] } {
		return
	    }
	}

	# If we cannot look up the command name and try to trace, Tcl is likely to 
	# become unstable.
	#
	if { [info commands $proc] ne {} } {
	    trace add execution $proc { enter leave } traceproc-print
	}
    }
 }

 proc traceproc { args } {
    set procs {}

    foreach { op patterns } $args {
	foreach pattern $patterns {
	    switch $op {
	     + { lappend procs {*}[info commands $pattern] }
	     - {
		intersect3 $procs [info commands $pattern] in1 in2 inB
		set procs $in1

		lappend ::traceprocExclude $pattern
	     }

	     = {	trace add execution proc leave "traceproc-add $pattern" }
	    }
	}
    }

    intersect3 $procs "trace traceproc-print puts ::puts set ::set" in1 in2 inB
    set procs $in1

    foreach proc $procs {
	trace add execution $proc { enter leave } traceproc-print
    }
 }

 # Modified to combine the call by name and returned list of 3 lists API.
 #
 proc intersect3 { list1 list2 { inList1 {} } { inList2 {} } { inBoth {} } } {
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
