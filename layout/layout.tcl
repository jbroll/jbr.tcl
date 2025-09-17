set layout.debug 0

proc transpose {matrix} {		# From http://wiki.tcl.tk/2748
    set res {}
    for {set j 0} {$j < [llength [lindex $matrix 0]]} {incr j} {
	set newrow {}
	foreach oldrow $matrix {
	    lappend newrow [lindex $oldrow $j]
	}
	lappend res $newrow
    }
    return $res
}

proc K { x y } { set x }

proc shift { V } {
    upvar $V v
    K [lindex $v 0] [set v [lrange [K $v [unset v]] 1 end]]
}

proc yank { opt listName { default {} } } {
	upvar $listName list

    if { [set n [lsearch $list $opt]] < 0 } { return $default }

    K [lindex $list $n+1] [set list [lreplace [K $list [unset list]] $n $n+1]]
}
proc yink { opt listName { bool 1 } } {
	upvar $listName list

    if { [set n [lsearch $list $opt]] < 0 } {
	if { $bool } { 	return 0 
	} else {	return {}
	}
    }

    set list [lreplace [K $list [unset list]] $n $n]

    if { $bool } { 	return 1
    } else {		return $opt
    }
}

proc char { list char } {
    if { [string length [lindex $list 0]] == 1 } { return 1 }

    string compare [string range [lindex $list 0] 0 [string length $char]-1] $char
}

proc array.map { array string { char {} } } {
	upvar $array A
	set map {}
	foreach { name value } [array get A] { lappend map $char$name $value }

	string map $map $string
}
proc layout.register { w args } {
	    global Options

	if { [yink -container args]  } { lappend ::Containers $w }
	if { [set posi [yank -positional args 0]] } { set ::Positional($w) $posi }
	if { [string compare [set proc [yank -proc       args]] {}] } { 
		proc $w {*}$proc
	}

	set Options($w) [array.map Options [lindex $args 0] %]
}

      set Containers {}

array set Options {
    core	{ -text -relief -padx -pady -background -foreground -height -width -justify -font -relief }
    pad		{ -padx -pady }
}


layout.register     row	 	-container { -sticky -weight -background }	-proc { { w args } { layout $w -type row -verb [yank -verb args 0] {*}$args } }
layout.register     col	 	-container { -sticky -weight -background }	-proc { { w args } { layout $w -type col -verb [yank -verb args 0] {*}$args } }

layout.register     button	{ %core %pad -command }
layout.register     text	{ %core %pad -anchor }
layout.register     label	{ %core %pad -anchor }
layout.register     entry	{ %core %pad -validate -vcmd -validatecommand -state -disabledbackground -disabledforeground }
layout.register     radiobutton	{ %core %pad -command -variable -value }
layout.register     checkbutton	{ %core %pad -command -variable -onvalue -offvalue }
layout.register     optmenu	{ %core %pad -command -textvariable -listvariable }
layout.register     scale	{ %core %pad -from -to -orient -resolution -digits -showvalue -tickinterval -length -sliderlength -sliderrelief -variable -command -label -value }

layout.register     ttk::separator { -orient -style -cursor }

proc layout.macro   { macro body } { proc layout.macro.$macro {} [list uplevel $body] }
proc layout.option  { macro body } { proc layout.option.$macro {} [list uplevel $body] }
proc layout.replace { args } { upvar spec spec;  set spec [lreplace [K $spec [unset spec]] 0 0 {*}$args]; lindex $args 0 }
	
layout.macro @  { layout.replace label       -text 	   }
layout.macro =  { layout.replace entry       -textvariable }
layout.macro !  { layout.replace button      -text 	   }
layout.macro *  { layout.replace radiobutton -text 	   }
layout.macro ~  { layout.replace checkbutton -text 	   }
layout.macro _  { layout.replace ttk::separator -orient horizontal }
layout.macro |  { layout.replace ttk::separator -orient vertical   }
layout.macro ?  { layout.replace optmenu  -textvariable }
layout.macro ?+ { layout.replace combobox -textvariable }
layout.macro <--> { layout.replace scale -variable }

layout.option << { layout.replace -justify left   	   }
layout.option >> { layout.replace -justify right  	   }
layout.option >< { layout.replace -justify center 	   }

proc layout.define { name args body } { proc $name $args "subst  {$body}" }


proc layout.default.value    { item option w defs Defs } { 
    upvar $defs d;  set d(-text) 
}
proc layout.default.default { join map item option w defs Defs } {
    upvar $defs d;
    upvar $Defs D;

    set value [string map  $map [string trim [set d(-text)]]]

    if { [catch { set prefix $D(-$item.$option.prefix) }] } {
        if { [catch { set prefix $D(-$option.prefix) }] } {
            set prefix ""
            set value [string map $map [string tolower [string trim [set d(-text)]]]]
        }
    }

    return "$prefix$join$value"
}
proc layout.default.variable { item option w defs Defs } {
        upvar $defs d;
	upvar $Defs D;

	layout.default.default :: { " " _ } $item $option $w d D
}

proc layout.radiobutton.value    { item option w defs Defs } { upvar $defs d;  set d(-text) }
proc layout.checkbutton.variable { item option w defs Defs } { upvar $defs d;  set d(-text) }
proc layout.button.command       { item option w defs Defs } {
        upvar $defs d;
	upvar $Defs D;

	layout.default.default { } { " " - } $item $option $w d D
}

proc layout.parent { w } { join [lrange [split $w .] 0 end-1] . }

proc layout.options { comm item name options } { set options }


# Layout Notebook ----------------------------
#
proc layout.notebook.notebook { w args } {
    set verb   [yank -verb args 0]

    ttk::notebook $w {*}[lrange $args 0 end-1]

    layout -in $w -type notebook -verb $verb [lindex $args end]
}
proc layout.notebook.page { w text args } {
    set verb   [yank -verb args 0]

    [layout.parent $w] add [row $w -verb $verb [lindex $args end]] -text $text {*}[lrange $args 0 end-1]

    return $w
}
proc layout.notebook.grid { w args } { return $w }

layout.macro notebook { return layout.notebook.notebook }
layout.macro page     { return layout.notebook.page }
layout.register     notebook 	-container { }
layout.register     page 	-container { } -positional 1


# Layout Paned -------------------------------
#
proc layout.paned.paned { w args } {
    panedwindow $w {*}[lrange $args 0 end-1]

    layout -in $w -type paned [lindex $args end]
}
proc layout.paned.pane { w args } {
    [layout.parent $w] add [row $w [lindex $args end]] {*}[lrange $args 0 end-1]

    return $w
}
proc layout.paned.grid { w args } { return $w }

layout.macro paned { return layout.paned.paned }
layout.macro pane  { return layout.paned.pane  }
layout.register     paned 	-container { }
layout.register     pane 	-container { } 


proc layout.col.grid { w llchild llsticky row col } {
    set llchild  [transpose $llchild]
    set llsticky [transpose $llsticky]

    layout.row.grid $w $llchild $llsticky $col $row
}

proc layout.row.grid { w llchild llsticky row col }  {
    foreach lchild  $llchild	\
	    lsticky $llsticky {

	grid {*}$lchild 

	foreach child  $lchild	\
		sticky $lsticky {
	    switch -- $child {
	     x - ^ - - { }
	     default { grid configure $child -sticky $sticky }
	    }
	}
    }

    foreach { rc wgt } $row { grid    rowconfigure $w $rc -weight $wgt }
    foreach { rc wgt } $col { grid columnconfigure $w $rc -weight $wgt }

    return $w
}

proc layout { w args } {
    set type   [yank -type args row]
    set verb   [yank -verb args 0]

    set lchild  {};  set llchild  {}
    set lsticky {};  set llsticky {}

    set spec  [lindex $args end]
    set args  [lrange $args 0 end-1]
    set defs(-sticky) [set -sticky [yank -sticky args]]

    if { $w eq "-in" }	{ set w [shift args]
    } else {
        if { [lsearch $args -text] >=0 } { ttk::labelframe $w {*}$args
        } else  			             { frame           $w {*}$args }
    }

    if { $w eq "." } { set w {} }

    set dbg1 0

    set spec [regsub -all -line -- {((^[ \t]*)|([ \t]+))#.*$} $spec { }]	; # Remove comments

    set row 0
    set col 0
    set hint {}

    while { [llength $spec] } {
	# Look ahead for special notation
	#
	if { ![char [lindex $spec 1] .]  }    { set name $w[lindex $spec 1];  set spec [lreplace $spec 1 1]
	} else                                { set name $w.w[incr n] }
	while { ![char [lindex $spec 1] ::] } { lappend  [lindex $spec 1] $name ;  set spec [lreplace $spec 1 1] }

	if { [catch { layout.macro.[lindex $spec 0] } reply] } {
		set comm [set item [shift spec]]
	} else {
		set comm $reply
		set item [shift spec]
	}

	switch -glob -- $item {
	    -rowweight	{ set RW($row) [shift spec]; continue }
	    -colweight	{ set CW($col) [shift spec]; continue }

	    . { continue }
	    &    {
            if { ![llength $lchild] } { continue }

            lappend llchild  $lchild;   set lchild  {}
            lappend llsticky $lsticky;  set lsticky {}

            incr row
            set col 0

            continue
	    }
	    ^ - x - -	{
		incr col [expr { $item eq "x" }]
		lappend lchild  $item
		lappend lsticky {}
		continue
	    }
	    +*  { catch { unset defs($item) } }
	    -*	{ 	set defs($item) [shift spec]
			continue
		}
	    {\?\?} { set dbg1 1; continue }

	    default {
		set args {}

		set posi {}
		if { [info exists ::Positional($item)] && $::Positional($item) } {
		    set posi [lrange $spec 0 $::Positional($item)-1]
		    set spec [lrange $spec $::Positional($item) end]
		}


		while { ![char $spec -] } {

		    lappend  args [shift spec] [string map "%w $name" [shift spec]]
		    catch { layout.option.[lindex $spec 0] } ; #reply ; # puts $reply
		}

		set sticky [yank -sticky args $defs(-sticky)]

		array set d $args

		if { [info exists ::Options($item)] } {
		    foreach option $::Options($item) {
			set opt [string range $option 1 end]

			if { ![catch { set d($option) [string map "%w $name" $defs($option)] }] } 	{ continue }
			if { ![catch { set d($option) [string map "%w $name" $defs(-$item.$opt)] }] }	{ continue }
			if {  [catch { set d($option) [layout.$item.$opt $item $opt $name d defs] } reply] } {
			    catch { set d($option)  [layout.default.$opt $item $opt $name d defs] } reply
			}
		    }
		}

		array set d $args

		if { [info exists d(-hint)] } {
		    set hint $d(-hint)
		    unset d(-hint)
		} else {
		    set hint {}
		}

		set map {}
		foreach { opt value } [array get d] {
		    lappend map [regsub {^-} $opt %] $value
		}
		foreach { opt value } [array get d] {
		    set d($opt) [string map $map $value]
		}

		set args [layout.options $comm $item $name [array get d]]
		if { [lsearch -exact $::Containers $item] >= 0 } { lappend args [shift spec] }

		if { $verb } { puts "$item $name {*}$posi {*}$args" }
		if { [set ::layout.debug] || $dbg1 } {
		    puts "{*}$comm $name {*}$posi {*}$args"
		    set dbg1 0
		}
		if { [catch { set child [uplevel [list {*}$comm $name {*}$posi {*}$args]] } reply] } {
		    puts stderr "$comm $name $posi $args"
		    error $reply
		}

	 	if { $hint != {} } {
		    set ::Hints($child) $hint
		    set hint {}
		}

		array unset d
	    }
	}

	if { $child ne {} } {
	    foreach c $child {
		lappend lchild  $c
	        lappend lsticky $sticky
	    }

	    incr col [llength $child]
	}
    }
    if { $lchild ne {} } {
	lappend llchild  $lchild;   set lchild  {}
    	lappend llsticky $lsticky;  set lsticky {}
    }

    if { ![string compare $w {}] } { set w . }

    layout.$type.grid $w $llchild $llsticky [array get RW] [array get CW]
}


