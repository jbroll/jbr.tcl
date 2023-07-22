
package require TclOO
package require jbr::template
package require jbr::dict
package require jbr::func
package require jbr::unix

oo::class create template-environment {

    constructor { args } {
        variable macros {}
        variable macroArgs {}
        variable macroPaths {}

        my macros {*}$args
    }

    # Create a macro <name>
    #
    #   macro name # value          - A macro <name> that evaluates to <value> with numeric substitution.
    #   macro name <args ..> value  - A macro <name> that evaluates to <value> with named substitution. 
    #
    method macro { name args } {
        variable macroArgs
        variable macros 

        if { [llength $args] == 2 && [lindex $args 0] eq "#" } {
            set declairedArgs #
        } else {
            set declairedArgs [lrange $args 0 end-1]
        }

        dict set macroArgs $name $declairedArgs
        dict set macros $name [lindex $args end]
    }

    # Find macros in files along a list paths.
    #
    method macros { args } {
        variable macroPaths
        set macroPaths $args
    }

    # Append the <text> to the macro named <name>
    #
    method append { name text } {
        variable macros 
        dict append macros $name $text
    }

    # Include the macro <name> in the expansion.  This is typically abbreviated "[< name ... ]"
    #
    # Several forms are acceptable for macro arguments:
    #
    #   [< <name> # [<value> ...] ]     - Numberic argument substitution
    #   [< <name> <value> ...]          - An argument list where names are provided in the declariation
    #   [< <name> <name> <value> ...]   - An argument list where names are provided in a key value list.
    #   [< <name> <dict> ]              - A single argument that is a valid dict.
    #
    method include { name args } {
        variable macros
        variable macroArgs
        variable macroPaths

        set declairedArgs [dict get? $macroArgs $name]

        # It is necessary to allow control of numberic substitution here so the file based 
        # macros can use it.
        #
        if { [lindex $args 0] eq "#" } {
            set args [lassign $args declairedArgs]  ; # Force numeric args substitutions
        } else {
            set names $declairedArgs                ; # Use the names if provided.
        }

        if { $declairedArgs eq "#" } {
            set args [zip [iota 1 [llength $args]+1] $args]
        } else {
            if { [llength $declairedArgs] } {       ; # There are names, zip them with the values

                # Support default args similar to proc
                #
                set defaults [join [lmap arg $declairedArgs { if { [llength $arg] <= 1 } { continue }; set arg }]]
                set args [zip -stop-short [lmap arg $declairedArgs { lindex $arg 0 }] $args]
                set args [dict merge $defaults $args]
            } elseif { [llength $declairedArgs] == 0 && [llength $args] == 1 } {   ; # There are no names and a single dict is passed
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
