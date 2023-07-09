
proc with { resource as variable { free {} } { block {} } } {
    if { $as eq "as" } {
        uplevel [list set $variable $resource]
    } else {
        uplevel [list set $resource $variable]
    }

    if { $block eq {} } {
        set block $free
        set free "chan close \$$variable"
    }
    try {
        uplevel $block
    } finally {
        uplevel $free
    }
}
