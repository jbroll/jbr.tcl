
 # Us this instead of proc to create an iterator
 #
 proc iterator { name args body } {
    proc $name $args [subst {
	yield
	$body
	return -code break
    }]
 } 

 # Call a proc which yields on each value and finally 
 # calls [return -code break].
 #
 proc iternext {} { return coco[incr ::iternext] }
 proc iterate { args } {
     set body [lindex $args end]
    set args [lrange $args 0 end-1]

    foreach { var iterator } $args {
	set cmd [iternext]
	uplevel "coroutine $cmd $iterator"

	if { [llength $var] > 1 } {
	    lappend iters "foreach { $var } \[$cmd] { break }"
	} else {
	    lappend iters "set $var \[$cmd]"
	}
    }

    tailcall while 1 "[join $iters \n]$body"
 }


 # An example
 #
 iterator iota-iter { n { m {} } } {
    if { $m eq {} } {
	set m $n
	set n 0
    }
    for { set i $n } { $i < $m } { incr i } {
	yield $i
    }
 }

 #iterate n { iota-iter 10 } {
 #    puts $n
 #}
