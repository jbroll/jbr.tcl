
proc parse-milli { clock } {
    lassign [split [lindex $clock 3] .] time milli
    lset clock 3 $time
    set time [clock scan $clock]
    if { $milli ne {} } {
	set time [expr $time + [scan $milli %d]/1000.0]
    }

    return $time
}

proc date-milli {} {
    set milli [clock milliseconds]
    set clock [clock format [expr $milli /1000] -format "%a %b %d %T %Y"]
    lset clock 3 "[lindex $clock 3].[format %03d [expr $milli % 1000]]"

    return $clock
}




