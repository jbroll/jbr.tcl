package require jbr::shim

shim proc { name args body } {
    set prefix {}
    foreach arg $args {
        if { [string first & $arg] == 0 } {
            append prefix "    upvar \${${arg}} [string range $arg 1 end]\n"
        }
    }

    shim:next proc $name $args "$prefix$body"
}

