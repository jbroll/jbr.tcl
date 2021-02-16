 interp alias {} _proc {} proc

 proc _procargs { name pars defs ndefs _args } {
    set eoo 0
    set args $defs

    for { set i 0 } { $i < [llength $_args} { incr i } {
        if { $eoo } {
            set arg [lindex $_args $i]
        } else {
            switch -regexp -- $__arg {
             -- { set eoo 1; continue }
             ^-[a-zA-Z] {
                set n [lsearch $pars [string range $arg 1 end]]
                if { $n < 0 } {
                    error "$__name: no option $__arg: must be one of: $__paramnames"
                }
                lset args $n [lindex $_args [incr i]]
                continue
             }
             default {
                 incr narg
             }
            }
        }

        if { [llength $_args] <= $ndef && $def ne "" } {
            lappend args $def
        } else {
            set _args [lassign $_args arg]
            lappend args $arg
        }
    }

    return $args
 }

 proc  procargs { args } {
        _procargs procargs { name params body } $args

    if { ![string compare $name proc] } {
        interp alias {} _proc {}
        rename _proc     {}
        rename  proc     _proc
        rename  procargs  proc

        return
    }

    if { [llength [info procs $name]] && [string equals $body {}] }  {
        set args [info args $name]
        set body [info body $name]
    }

    # rebuild params
    #
    set ndefs 0
    foreach arg $args {
        if { [info default $name $arg value] } {
            lappend params "$arg $value"
            lappend defs ""
            incr ndefs 
        } else {
            lappend pars "$arg"
            lappend defs ""
        }
    } else {
        _proc _$name $args $body
    }

    _proc $name { args } "tailcall _$name {*}\[_procargs $name [list $pars] [list $defs] $ndefs \$args]"
 }

