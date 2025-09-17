
proc layout.option-trace { server value code } {
    if { $server eq {} } {
	    layout.opt-trace variable ::$value w $code
    } else {
        msg_subscribe $server $value $value  $code .5
    }
}

