
proc seconds { time { now "" } } {

    if { $now eq "" } {
        set now [clock seconds]
    }
    if { $time eq "" } {
        return $now
    }

    set time [expr [string map { 
        m "*60" 
        h "*3600" 
        d "*[expr 60*60*24]" 
        w "*[expr 60*60*24*7]" 
        t "*[expr 60*60*24*30]" 
        y "*[expr 60*60*24*365]" 
    } $time]]

    if { $time < 0 } {
        set time [expr $now + $time]
    }

    return $time
}

