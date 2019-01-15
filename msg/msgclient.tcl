#!/bin/sh
# \
exec wish "$0" "$@"

lappend auto_path $env(MMTITCL)
#source ../msg.tcl

set msg_editing {}

set subscriptions {}

proc ret_copy { name indx op } {
	upvar $name value
	global msg_editing

    if { [string compare $msg_editing $name] } {
    	global ${name}.buffer
	set ${name}.buffer $value
    }
}

proc ret_entry { w args } { 
    set var [lindex [split $w .] end]
    set mode rw
    set pass {}

    set state normal

    foreach { option value } $args {
     switch -exact -- $option {
	-var    { set var  $value }
	-mode   { set mode $value }
	default { set pass "$pass $option $value" }
     }
    }

    if { ![string compare $mode ro] } {
	set state disabled
    }


    global $var ${var}.buffer
 
    catch {
	upvar #0 $var v
	set ${var}.buffer $v
    }

    trace variable ${var} w { ret_copy }
    
    eval entry $w -textvariable ${var}.buffer -justify right -state $state $pass

    # This forces a trace on the return key
    #
    bind $w <Key-Return> "set $var \[%W get]"
    bind $w <FocusIn>    " 				\n\
	global msg_editing				\n\
	set msg_editing $var				\n\
    "
    bind $w <FocusOut>   " 				\n\
	upvar #0 $var        val			\n\
	upvar #0 $var.buffer buf			\n\
							\n\
	if { [string compare \$val \$buf] != 0 } {	\n\
	    %W delete 0 end				\n\
	    %W insert 0 \$val				\n\
	}						\n\
	set msg_editing {}				\n\
    "

    return $w
}

proc msg_entry { server lab w args } {
    set var  [lindex [split $w .] end]
    set pre  {}
    set post {}
    set pass {}

    set def  {}
    set init Up
    set code {}

    foreach { option value } $args {
     switch -exact -- $option {
	-var    { set var $value
		  set pass "$pass $option $value"
		}
	-pre    { set pre  $value	}
	-post   { set post $value	}

	-def    { set def $value	}
	-init   { set init $value	}
	-mode   { set mode $value
		  set pass "$pass $option $value"
		}
	-code   { set code $value	}
	default {
	    set pass "$pass $option $value"
	}
     }
    }

    if { ![string compare $mode ro] } {
	set init Server
    }

    msg_variable $server $var $var w $def $init $code 

    label ${w}_l -text $lab -anchor w
    eval ret_entry $w $pass

    return "${w}_l $pre $w $post"
}

proc lab_entry { lab w args } {
    set var  [lindex [split $w .] end]
    set pre  {}
    set post {}
    set pass {}

    foreach { option value } $args {
     switch -exact -- $option {
	-var    { set var  $value	}
	-pre    { set pre  $value	}
	-post   { set post $value	}
	default {
	    set pass "$pass $option $value"
	}
     }
    }

    global $var
    label ${w}_l -text $lab -anchor w
    eval entry $w -textvariable $var -justify right $pass

    return "${w}_l $pre $w $post"
}

proc msg_run { server command args } {

	set args [subst $args]

	msg_cmd $server "$command $args"
}

proc msg_cmdbox { server w item comment } {
    set len [llength $comment]

    if { $len == 1 } {
    }

    set label $item
    if { ![string compare [lindex $comment [expr $len-2]] --] } {
	set label   [lrange $comment [expr $len-2] [expr $len-1]]
	set comment [lrange $comment 0 [expr $len-3]]
    }

    regsub -all -- \001                 $label { } label
    grid [button ${w} -text $item] [label ${w}_x -text $label] - - -sticky news

    set options {}
    set alist   {}
    set name    {}
    foreach { option value } $comment {
	switch -- $option {
	    -name {
		if { ![string compare $name {}] } {
		    set name $value
		    set alist "$alist \$${item}_$name"
		} else {
		    msg_varbox $server ${w}_$name ${item}_$name "-- $name $options -sub no"
		    set name    $value
		    set alist "$alist \$${item}_$name"
		    set options {}
		}
	     }
	     default { set options "$options $option $value" }
	}
    }
    if { [string compare $name {}] } {
	msg_varbox $server ${w}_$name ${item}_$name "-- $name $options -sub no"
    }

    set command "msg_run $server $item $alist"

    ${w} configure -command $command
}

proc msg_varbox { server w item comment } {

	global subscriptions

	set sub {}
	set fmt {}
	set unt {}
	set lab {}
	set dsh {}
	set ini Up
	set def {}
	set mod rw

	if { [llength $comment] == 1 } {
	    set lab $comment
	} else {
	    foreach { option value } $comment {
	     regsub -all -- \001                 $value { } value
	     switch -exact -- $option {
	      -sub	{ set sub $value }
	      -format 	{ set fmt $value }
	      -units 	{ set unt $value }
	      -dash 	{ set dsh $value }
	      -init 	{ set ini $value }
	      -default 	{ set def $value }
	      -mode 	{ set mod $value }
	      --	{ set lab $value }

	     }
	    }
	}

	if { ![string compare $lab {}] } {
	    set lab [string trim $item]
	}

	switch $sub {
	 no 	 {}
	 {} 	 { lappend subscriptions "msg_subscribe $server $item $item {} 1" 	}
	 default { lappend subscriptions "msg_subscribe $server $item $item {} $sub"	}
	}
   
        if { ![string compare $dsh -] } {
	    eval grid [msg_entry $server $lab $w -var $item -pre "-" 	\
				-def $def -init $ini -mode $mod]	\
		      [label [string tolower ${w}_u] -text $unt -anchor w] \
			-sticky news
	} else {
	    eval grid x [lab_entry $lab $w -var $item] 				\
			[label ${w}_u -text $unt] -sticky news
	}
}

proc up { } {
	global Title
	wm title . "$Title -- Up"
}
proc down { } {
	global Title
	wm title . "$Title -- Down"
}



# Scrolled canvas taken from Ch. 31 Practical Programming in Tcl/Tk -- Welch

set top ""
frame $top.c
set canvas [canvas $top.c.canvas -width 200 -height 200 \
	-yscrollcommand [list $top.c.yscroll set] ]
scrollbar $top.c.yscroll -orient vertical \
	-command [list $top.c.canvas yview]
pack $top.c.yscroll -side right -fill y
pack $top.c.canvas -side left -fill both -expand true
pack $top.c -side top -fill both -expand true

set w [frame $top.c.canvas.f -bd 0]
$canvas create window 0 0 -window $w -anchor nw

        if { $argc == 1 } {
	    set server [lindex $argv 0]
	} else {
	    set server GENERIC
	}

	set Title "$server $env($server)"

	msg_client $server up down

	msg_list $server P

	foreach { line } $P {
	    set type    [lindex $line 0]
	    set item    [lindex $line 1]
	    set comment [lindex $line 2]

	    if { ![string compare $type registered] } {
		if { ![string compare $item set] } { continue }
		if { ![string compare $item get] } { continue }
		if { ![string compare $item ack] } { continue }
		if { ![string compare $item nak] } { continue }
		if { ![string compare $item sub] } { continue }
		if { ![string compare $item uns] } { continue }
		if { ![string compare $item lst] } { continue }
		if { ![string compare $item ACK] } { continue }
	    }

	    regsub -all -- {[ 	]} 		$comment \001 comment

	    regsub -all -- \001*-sub\001+	$comment { -sub } comment
	    regsub -all -- \001*-name\001+	$comment { -name } comment
	    regsub -all -- \001*-format\001+ 	$comment { -format } comment
	    regsub -all -- \001*-units\001+	$comment { -units } comment
	    regsub -all -- \001*-default\001+	$comment { -default } comment
	    regsub -all -- \001*-mode\001+	$comment { -mode } comment
	    regsub -all -- \001*-init\001+	$comment { -init } comment
	    regsub -all -- \001*--\001+ 	$comment { -- } comment

	    if { ![string compare $type server] } {
		set msgname $item
		set msgport $comment
	    }


	    if { ![string compare $type server] } {
		set Title "$item $comment"
		up
	    }

	    set child $w.[string tolower $item]
	    regsub -all {[[\]]} $child {} child

	    if { ![string compare $type published] } {
		msg_varbox $server $child $item "-dash - $comment"
	    }
	    if { ![string compare $type registered] } {
		msg_cmdbox $server $child $item $comment
	    }
	}


tkwait visibility $child
set bbox [grid bbox $w 0 0]
set incr [lindex $bbox 3]
set width [winfo reqwidth $w]
set height [winfo reqheight $w]
$canvas config -scrollregion "0 0 $width $height"
$canvas config -yscrollincrement $incr
set height [expr $incr * 10]
$canvas config -width $width -height $height

foreach command $subscriptions {
	eval $command
}

