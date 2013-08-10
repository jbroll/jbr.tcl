
proc ::tcl::string::chunk { data { size 70 } } { 
    set len [expr { $size -1 }]

    for { set i 0 } { $i < [string length $data] } { incr i $size } {
	lappend reply [string range $data $i $i+$len]
    }

    set reply
}

namespace ensemble configure string -map [dict merge [namespace ensemble configure string -map] {chunk ::tcl::string::chunk}] 

