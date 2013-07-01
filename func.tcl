
proc iota { fr to { in 1 } } {
    for { set res {} } { $fr <= $to } { incr fr $in } {lappend res $fr } 
    set res
}

proc map { args } {
    return [uplevel [subst {
	set _[info frame] {}
	foreach [lrange $args 0 end-1] { lappend _[info frame] \[[lindex $args end]] }
	set _[info frame]
    }]]
}

proc zip { args } {
    set n [iota 0 [expr [llength $args]-1]]

    map {*}[join [map a $n { list $a [lindex $args $a] }]] "list [join [map i $n { concat $$i }]]"
}

#puts [zip { a b c } { 1 2 4 } { x y z }]


