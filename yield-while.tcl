
proc yield-while-callback { proc name indx op  } {
    if { $proc eq [info coroutine] } {
	puts "yield-while-callback for $proc in $proc"
	return
    }
    if { $proc eq {} } {
	puts "yield-while-callback on {}"
	return
    }

    after idle $proc		; # Resume the co-routine from the global context.
}

proc yield-while { expr args } {
#puts "yield-while [info coroutine] : $expr" 
    foreach var $args { trace add variable $var write [list yield-while-callback [info coroutine]] }
    #puts "uplevel [list subst $expr]"
    #puts "[uplevel [list subst $expr]]"
    while { [uplevel expr [list $expr]] } { yield }
    foreach var $args { trace rem variable $var write [list yield-while-callback [info coroutine]] }
}
