
proc shift { V } {
    upvar $V v
    K [lindex $v 0] [set v [lrange [K $v [unset v]] 1 end]]
}

proc template:if { args } {
    set cmd [subst { if { [shift args] } { return \[subst {[shift args]}] } }]

    while { [llength $args] } {
        switch [shift args] {
         else   { append cmd [subst   { else { return \[subst {[shift args]}] } }] }
         elseif { append cmd [subst   { elseif { [shift args] } { return \[subst {[shift args]}] } }] }
        }
    }

    return [uplevel $cmd]
}

proc template:foreach { args } {
    return [uplevel [subst {
        set _[info frame] {}
        foreach [lrange $args 0 end-1] { append _[info frame] \[subst {[lindex $args end]}] }
        set _[info frame]
    }]]
}

proc template:switch { value cases } {
    foreach { case code } $cases {
        switch $code {
               - { lappend body $case - }
         default { lappend body $case "return \[subst {$code}]" }
        }
    }

    return [uplevel [subst { switch $value { $body } }]]
}

proc template:subst { string } {
    uplevel [list subst [string map { \\ \\\\ [! [ "[: " "[: " [* [* [? [? [ \\[ } $string]]
}


interp alias {} : {} template:foreach
interp alias {} * {} template:switch
interp alias {} ? {} template:if


