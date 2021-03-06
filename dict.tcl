
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

proc ::tcl::dict::get@ {args} {

    try { 		 ::set x [dict get {*}[lrange $args 0 end-1]]
    } on error message { ::set x [lindex $args end] }

    return $x
}
namespace ensemble configure dict -map [dict merge [namespace ensemble configure dict -map] {get@ ::tcl::dict::get@}] 


proc ::tcl::dict::import { dict args } {
    if { [llength $args] == 0 } {
        set args [dict keys $dict]
    }

    uplevel 1 [list dict update $dict {*}[zip $args $args] {}]
}
namespace ensemble configure dict -map [dict merge [namespace ensemble configure dict -map] {import ::tcl::dict::import}] 

proc print {dict {pattern *}} {
   set longest [tcl::mathfunc::max 0 {*}[lmap key [dict keys $dict $pattern] {string length $key}]]
   dict for {key value} [dict filter $dict key $pattern] {
      puts [format "%-${longest}s = %s" $key $value]
   }
}
namespace ensemble configure dict -map [dict merge [namespace ensemble configure dict -map] {print ::tcl::dict::print}] 
