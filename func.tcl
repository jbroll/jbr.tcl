
proc K { x y } { set x }

proc +   { x y } { expr $x + $y }
proc *   { x y } { expr $x * $y }
proc sum { lst } { foldl + 0 $lst }
proc sqr { x   } { expr $x * $x }
proc max { x y } { expr $x > $y ? $x : $y }


proc iota { fr { to {} } { in 1 } } {
    if { $to eq {} } {
	set to $fr
	set fr 0
    }
    set fr [expr $fr]
    set to [expr $to]

    for { set res {} } { $fr <= $to+$in*0.5 } { set fr [expr $fr+$in] } {lappend res $fr } 
    set res
}

proc jot { { nx - } { x0 - } { x1 - } { xi - } } {
    if { $nx eq "-" } { set nx 10 }
    if { $x0 eq "-" } { set x0  0 }
    if { $x1 eq "-" } { set x1 [expr { $x0+$nx-1.0 }] }
    if { $xi eq "-" } { set xi [expr { ($x1-$x0)/($nx-1.0) }] }

    #puts "jot $nx $x0 $x1 $xi"

    if { $nx == 1 } {
	expr { ($x0+$x1)/2.0 }
    } else {
	#puts [iota $x0 $x1 $xi]
	iota $x0 $x1 $xi
    }
}

proc zip { args } {
    set n [iota 0 [expr [llength $args]-1]]

    join [map {*}[join [map a $n { list $a [lindex $args $a] }]] "list [join [map i $n { concat $$i }]]"]
}



proc map { args } {
    uplevel [subst {
	set _[info frame] {}
	foreach {*}[list [lrange $args 0 end-1]] { lappend _[info frame] \[[lindex $args end]] }
	set _[info frame]
    }]
}

proc pick {func list} {
    set ret [list]
    foreach item $list {
	if {[eval $func [list $item]]} {
	    lappend ret $item
	}
    }
    return $ret
}

proc foldl {func res list} {
    foreach item $list { set res [eval $func [list $res $item]] }
    set res
}

proc foldr {func res list} {
    for {set i [llength $list]} {$i > 0} {incr i -1} {
	set res [eval $func [list [lindex $list [expr {$i-1}]] $res]]
    }
    set res
}

proc lremove { list value } {
    set indx [lsearch $list $value]

    lreplace $list $indx $indx
}

proc shuffle list {		# http://wiki.tcl.tk/941 shuffle10a
    set len [llength $list]
    while {$len} {
	set n [expr {int($len*rand())}]
	set tmp [lindex $list $n]
	lset list $n [lindex $list [incr len -1]]
	lset list $len $tmp
    }
    return $list
}

proc memo { proc } {
    rename $proc _$proc

    proc $proc { args } [subst -nocommands { 
	if { [info exists ::_${proc}(\$args)] } { return [set ::_${proc}(\$args)] }

	set ::_${proc}(\$args) [_${proc} {*}\$args]
    }]
}

memo iota
