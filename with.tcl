
proc with { resource as variable { free {} } { block {} } } {
    if { $as ne "as" } {
        lassign [list $resource $variable] variable resource
    }
    uplevel [list set $variable $resource]

    if { $block eq {} } {
        set block $free
        set free [subst -nocommands { 
            if { [info command \$$variable] eq "" } {
                chan close \$$variable
            } else {
                \$$variable close
            }
        }]
    }
    try {
        uplevel $block
    } finally {
        uplevel $free
    }
}
