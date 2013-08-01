
proc ::tcl::dict::lappend2 {dict args} { 
    upvar 1 $dict d 

    if { ![dict exists $d {*}[lrange $args 0 end-1]] } { 
	dict set d {*}[lrange $args 0 end-1] [list [lindex $args end]]
    } else {
	::set list [dict get $d {*}[lrange $args 0 end-1]]
	::lappend list [lindex $args end] 
	dict set d {*}[lrange $args 0 end-1] $list
    }
} 

namespace ensemble configure dict -map [dict merge [namespace ensemble configure dict -map] {lappend2 ::tcl::dict::lappend2}] 


proc ::tcl::dict::get? {args} {

    try { 		 ::set x [dict get {*}$args]
    } on error message { ::set x {} }

    return $x
}

namespace ensemble configure dict -map [dict merge [namespace ensemble configure dict -map] {get? ::tcl::dict::get?}] 
