
proc layout.msg-setoption   { w option action data name indx op } {
    upvar $name value

    if { [catch { $w configure $option [$action $value $data] } reply] } {
	if { ![string equal [lindex $reply 0] invalid] } {
	    puts $reply
	}
    }
}

proc layout.msg-bind { w option server value } {
    set action layout.msg-echo
    set data   {}
    switch -glob $value {
	*@* { set action layout.msg-indx;  foreach { value data } [split $value @] break }
	*!* { set action layout.msg-xxec;  foreach { value data } [split $value !] break }
	*%* { set action layout.msg-hash;  foreach { value data } [split $value %] break }
    }

    if { $server eq {} } {
	     trace variable ::$value w      [list layout.msg-setoption         $w $option $action $data]
    } else {
	msg_subscribe $server $value $value [list layout.msg-setoption         $w $option $action $data] .5
    }
}

proc layout.msg-echo { value data } { return $value }
proc layout.msg-indx { value data } { return [lindex [set ::${data}] $value] }
proc layout.msg-xxec { value data } { return [{*}${data} $value] }
proc layout.msg-hash { value data } { 
    try { set reply [set ::${data}($value)] 
    } on error message {
	try { set reply [set ::${data}(default)]
	} on error message { puts "cannot lookup $value or default in $data" }
    }

    return $reply
}

proc layout.msg-vformat { format name args } {
    catch { set $name% [format $format [set ::$name]] }
}

proc layout.options { comm item w options } {
    set reply {}

    foreach { option value } $options {

	switch -regexp $value {
	 {^[^ ]*\:.+\,[^ ]+$} {
	    foreach { server name value } [split $value {[:,]}] break

	    layout.msg-bind $w $option $server $name
         }
	 {^[^: ]*:[^:]+$} {
	    set code {}
	    foreach { server value format } [split $value {[:%]}] break

	    if { $format ne {} } {
		set code "layout.msg-vformat %$format"
	    }

	    msg_subscribe $server [regsub -all {[^_A-Za-z0-9]} $value {}] $value $code .5

	    if { $format ne {} } {
		set value $value%
	    }

         }
	}
	lappend reply $option $value
    }

    return $reply
}

