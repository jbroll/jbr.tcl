
proc notebook { w args } {
    set spec  [lindex $args end]
    set args  [lrange $args 0 end-1]

    set book [ttk::notebook $w {*}$args]

    while { [llength $spec] } {
	set item [shift spec]

	if { ![char $spec .] } { set name $w[shift spec]
	} else { 		 set name $w.w[incr n]	}

	if { ![char $spec ::] } { set [shift spec] $name }

	switch -glob -- $item {
	    -*		{ set defs($item) [shift spec]	; continue }
	    default {
		set args {}

		while { ![char $spec -] } { lappend  args [shift spec] [string map "%w $name" [shift spec]] }

		if { [info exists ::Options(notebook:page)] } {
		    foreach { optn valu } [array get defs] {
			if { [lsearch $::Options(notebook:page) $optn] >= 0 } { set d($optn) $valu }
		    }
		}

		array set d $args
		set args [array get d]
		set body [shift spec]

       		$book add [row $name {*}$args $body] -text $item

		array unset d
	    }
        }
    }

    set w
}


