
proc with { variable = resource { free {} } { block {} } } {
    uplevel [list set $variable $resource]

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
