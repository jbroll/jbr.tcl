
proc combobox { w args } {
    set textvariable [yank -textvariable args]
    set listvariable [yank -listvariable args %vList]
    set command      [yank -command      args]

    set spec	     [lindex $args end]
    set args         [lrange $args 0 end-1]

    set list $spec

    set listvariable [string map "%v $textvariable" $listvariable]

    if { $list eq "" && $listvariable ne "" && [info exists ::$listvariable] } {
	set list [set ::$listvariable]
    } 
    if { $listvariable ne "" } {
	trace variable ::$listvariable w "$w configure -values [set ::$listvariable]"
    }
    if { ![info exists ::$textvariable] } {
	set ::$textvariable [lindex $list 0]
    }
    if { $command ne "" } {
	trace variable ::$textvariable w [string map "%w $w %v $textvariable" $command]
    }

    ttk::combobox $w -textvariable $textvariable -values $list {*}$args
}
