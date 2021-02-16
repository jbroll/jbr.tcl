
 proc shim:shift { name } {
    if { [info commands ${name}_shimmed] ne {} } { shim:shift ${name}_shimmed }
    rename $name ${name}_shimmed
 }

 proc shim { name args body } {
    shim:shift $name 
    proc   $name $args $body
 }

 proc shim:next { name args } {
    set level -1
    try {
        set name [regsub ^:: $name {}]

        while { ![regexp "^${name}(_shimmed)*$" [set shim [regsub ^:: [lindex [info level $level] 0] {}]]] } { incr level -1 }
    } on error message {
        set level -1
        catch {
            while { ![regexp "^${name}(_shimmed)*" [lindex [info level $level] 0]] } {
                incr level -1
            }
        }
        set shim $name
    }

    tailcall ${shim}_shimmed {*}$args
 }

