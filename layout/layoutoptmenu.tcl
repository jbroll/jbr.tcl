
proc optmenu { w args } {
    set     variable [yank     -variable args]
    set textvariable [yank -textvariable args]
    set listvariable [yank -listvariable args %vList]
    set command      [yank -command      args]

    set args         [lrange $args 0 end]
    set list {}

    if { $textvariable ne "" && $variable eq "" } {
	    set variable $textvariable
    }

    set listvariable [string map [list %v $variable] $listvariable]

    if { $listvariable ne "" && [info exists ::$listvariable] } {
	    set list [set ::$listvariable]
    } 
    if { $listvariable ne "" } {
	    trace variable ::$listvariable w "optmenu:setlist $w"
    }
    if { $textvariable eq "" } {
	    set textvariable $variable
    }
    if { ![info exists ::$textvariable] } {
	    set ::$textvariable [lindex $list 0]
    }
    if { $command ne "" } {
	    trace variable ::$variable w [string map "%w $w %v $variable" $command]
    }

    optmenu:create $w $variable $textvariable $list {*}$args
}

proc optmenu:setlist { w name indx op } {
    upvar $name valu
    optmenu:list $w $valu
}


proc optmenu:create {w varName varText list args} {
    upvar #0 $varName var

    set ::${w}(varName) $varName

    menubutton $w -textvariable $varText -indicatoron 0 -menu $w.menu 	 \
	    -relief raised -bd 2 -highlightthickness 1 -anchor c -padx 3 -pady 3 \
	    -direction flush {*}$args
    menu $w.menu -tearoff 0
    foreach i $list {
    	$w.menu add radiobutton -label $i -variable $varName -indicatoron 1
    }
    return $w
}

proc optmenu:list { w list { vals {} } } {
    set varName [set ::${w}(varName)]

    $w.menu del 0 end
    set n 1
    foreach i $list v $vals {

        $w.menu add radiobutton -label $i -value $v -variable $varName -indicatoron 1 
	incr n
    }
    return $w.menu
}

