
proc seconds { { time -0 } { now 0 } } {
    milliseconds $time $now .001
}

proc milliseconds { { time -0 } { now 0 } { scale 1 } } {

    set op [string index $time 0]
    if { $op eq "+" || $op eq "-" } {
        set now [clock milliseconds]
    }

    set time [string map { 
        s *1000 
        m *60*1000 
        h *3600*1000 
        d *60*60*24*1000 
        w *60*60*24*7*1000 
        t *60*60*24*30*1000 
        y *60*60*24*365*1000 
    } $time]

    return [expr "($time + $now) * $scale"]
}

proc every {interval body} {
    after [milliseconds $interval] [list after idle [namespace code [info level
    try $body
}

