
package require TclOO
package require jbr::template
package require jbr::dict
package require jbr::func
package require jbr::unix

oo::class create template-environment {
    variable macros {}
    variable macroPaths {}

    constructor { args } {
        my macros {*}$args
    }

    method macro { name args } {
        variable macroTypes
        variable macros 

        if { [llength $args] == 2 && [lindex $args 0] eq "#" } {
            set type #
        } else {
            set type [list named {*}[lrange $args 0 end-1]]
        }

        dict set macroTypes $name $type
        dict set macros $name [lindex $args end]
    }
    method macros { args } {
        variable macroPaths
        set macroPaths $args
    }
    method append { macro text } {
        variable macros 
        dict append macros $macro $text
    }

    method include { name args } {
        variable macros
        variable macroTypes
        variable macroPaths

        set macroType [dict get@ $macroTypes $name dict]

        if { [lindex $args 0] eq "#" } {
            set args [lassign $args type]
        } else {
            set type [dict get@ $macroTypes $name dict]
        }

        if { $type eq "#" } {
            set names [iota 1 [llength $args]+1]
            set args [zip $names $args]
        } else {
            if { [llength $type] > 1 } {                                    # There are names, zip them with the values
                # Support default args similar to proc
                #
                set defaults [join [lmap arg [lrange $type 1 end] { if { [llength $arg] <= 1 } { continue }; set arg }]]
                set args [zip -stop-short [lmap arg [lrange $type 1 end] { lindex $arg 0 }] $args]
                set args [dict merge $defaults $args]
            } elseif { [llength $type] == 1 && [llength $args] == 1 } {     # There are no names and a single dict is passed
                set args [lindex $args 0]
            }
            # The default case is that there are no names and $args is already key value list.
        }

        if { [dict exists $macros $name] } {
            set text [dict get $macros $name]
        } else {
            foreach path $macroPaths {
                if { [file exists $path/$name] } {
                    set text [cat $path/$name]
                    break
                }
            } 
        }
        if { ![info exists text] } {
            error "no macro: $name"
        }

        dict with args {
            template:subst $text
        }
    }

    method subst { text } {
        template:subst [string map [list "\[< " "\[![self] include "] $text]
    }
}
