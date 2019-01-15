# Overlay a msg server subscription mini language on the options of the 
# canvas items.  If an item is specified as:
#
#	-option server:name,default
# fex:  -text PMACMMIRS:wfsg1XActual,0.0
#
#
# If the "server" part of the option spec is left blank (The value begins
# with a leading ":") the option will be bound to the global variable
# "name".  X, Y position, item coordinate geometry and configuration
# options may all be bound to global variables and subscribed msg values.
#
# a subscription to the named value of the server is established and the
# msg_subscribe call back code is set up to change the option to the value
# published by the server.  Often the value of the variable on the server
# will not map directly to the value necessary for setting the option.  A
# syntax is provided to allow the value to be mapped by indexing a list "@",
# looking in an array "%" or calling a proc "!".
#
#    server:name@lookup,0
#
# This will cause the option to the set to the value obtained by indexing
# the global variable "lookup" as a list with the value from server:name.
#
#
# 
 oo::class create canvas-msg {
    superclass canvas-oo
    variable   c C		; # The canvas "c" and data array "C"

    # Helpers to convert traced values into option values
    #
    method echo { value data } { return $value }
    method xxec { value data } { return [{*}${data} $value] }
    method indx { value data } { 
	if { $value eq {} } { set value 0 }
	if { ![string is integer $value] } { set value [expr { $value ? 1 : 0 }] }

	return [lindex [set ::${data}] $value]
    }
    method hash { value data } { 
	try { set reply [set ::${data}($value)] 
	} on error message {
	      set reply [set ::${data}(default)]
	}

	return $reply
    }

    # Helpers called from traces when values need to be updated
    #
    method set-x      { id op action name data var indx op } { upvar #0 $name value;  my amov   $id [my $action $value $data] - -; my draw $id }
    method set-y      { id op action name data var indx op } { upvar #0 $name value;  my amov   $id - [my $action $value $data] -; my draw $id }
    method set-r      { id op action name data var indx op } { upvar #0 $name value;  my amov   $id - - [my $action $value $data]; my draw $id }
    method set-coords { id op action name data var indx op } { upvar #0 $name value;  my coords $id [my $action $value $data]    ; my draw $id }
    method set-size   { id op action name data var indx op } { upvar #0 $name value;  my size   $id {*}[my $action $value $data] ; my draw $id }
    method set-option { id op action name data var indx op } { upvar #0 $name value;  $c itemconfigure $id $op [my $action $value $data] }

    # Set up the traces
    #
    method msgbind { id bindings } {
	foreach { server varname cb option } $bindings {
	    set action echo
	    set data   {}
	    switch -glob $varname {
		*@* { set action indx;  foreach { varname data } [split $varname @] break }
		*%* { set action hash;  foreach { varname data } [split $varname %] break }
		*!* { set action xxec;  foreach { varname data } [split $varname !] break }
	    }
	    if { $server eq {} } {
		trace variable ::$varname w             [namespace code [list my set-$cb $id $option $action $varname $data]]
	    } else {
		msg_subscribe $server $varname $varname [namespace code [list my set-$cb $id $option $action $varname $data]] .1
	    }
	    switch $action {
	     indx -
	     hash {
		trace variable ::$data w                [namespace code [list my set-$cb $id $option $action $varname $data]]
	     }
	    }
	}

	return $id
    }

    method parse  { axes arglist } {
	set argv {}
	set bind {}
	set axis  0
	set option [lindex $axes $axis]; set cb $option

	# Record and remove the option value binding syntax
	#
	foreach arg $arglist {
	    switch -regexp $arg {
	     -rot         { set option r   ; set cb r 		}
	     ^-[^0-9].*   { set option $arg; set cb option 	}
	     {^[^ ]*\:.*\,[^ ]*$} {
		foreach { server varname value } [split $arg {[ :,]}] break
		set arg $value

		if { [string index $option 0] eq "-" } { set cb option }

		lappend bind $server $varname $cb $option

		incr axis
		set  option [lindex $axes $axis]; set cb $option
	     }
	     default {
		incr axis
		set  option [lindex $axes $axis]; set cb $option
	     }
	    }

	    lappend argv $arg
	}

	return [list $argv $bind]
    }

    method rect { args } { lassign [my parse { x y size }   $args] args bind;  my msgbind [next {*}$args] $bind }
    method oval { args } { lassign [my parse { x y size }   $args] args bind;  my msgbind [next {*}$args] $bind }
    method line { args } { lassign [my parse { x y coords } $args] args bind;  my msgbind [next {*}$args] $bind }
    method poly { args } { lassign [my parse { x y coords } $args] args bind;  my msgbind [next {*}$args] $bind }
    method arc  { args } { lassign [my parse { x y size }   $args] args bind;  my msgbind [next {*}$args] $bind }
    method ngon { args } { lassign [my parse { x y size }   $args] args bind;  my msgbind [next {*}$args] $bind }
    method text { args } { lassign [my parse { x y -text }  $args] args bind;  my msgbind [next {*}$args] $bind }
    method csys { args } { lassign [my parse { x y }        $args] args bind;  my msgbind [next {*}$args] $bind }
 }
