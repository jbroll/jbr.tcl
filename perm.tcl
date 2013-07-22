
proc prod { d1 d2 { list {} } } {
    foreach x $d1 {
	foreach y $d2 {
	    if { $list eq {} } {
		set word $x$y
	    } else {
		set word [list {*}$x {*}$y]
	    }
	    lappend reply $word
    } }

    set reply
}
proc combi { alphabet n { list {} } { reply {} } } {
    if { $reply eq {} } { set reply $alphabet }

    if { $n > 1 } {
	set reply [prod $reply $alphabet $list]
	incr n -1
	if { $n > 1 } {
	    set reply [combi $alphabet $n $list $reply]
	}
    }

    set reply
}


proc perm { perm { sort {} } } {
    lappend reply [set perm [perm-init $perm $sort]]
    while { [set perm [perm-next $perm]] != {} } {
	lappend reply $perm
    }

    set reply
}
proc l- {list element} {
    set pos [lsearch -exact $list $element]
    lreplace $list $pos $pos
}
proc perm-init { perm { sort {} } } { lsort {*}$sort $perm }
proc perm-next { perm } {
    #-- determine last ascending neighbors
    set last ""
    for {set i 0} {$i<[llength $perm]-1} {incr i} {
	if {[lindex $perm $i]<[lindex $perm [expr {$i+1}]]} {
	    set last $i
	}
    }
    if {$last ne ""} {
	set pivot [lindex $perm $last]
	#-- find smallest successor greater than pivot
	set successors [lrange $perm $last end]
	set minSucc ""
	foreach i $successors {
	    if {$i>$pivot && ($minSucc eq "" || $i<$minSucc)} {
		set minSucc $i
	    }
	}
	concat [lrange $perm 0 [expr {$last-1}]] [list $minSucc] \
	    [lsort [l- $successors $minSucc]]
    }
}

