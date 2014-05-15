
proc traceproc-print { args } { puts $args }

proc traceproc { args } {
    set procs {}

    foreach { op pattern } $args {
	switch $op {
	 + { lappend procs {*}[info commands $pattern] }
	 - { intersect3 $procs [info procs $pattern] in1 in2 inB
	    set procs $in1
	 }
	}
    }

    intersect3 $procs traceproc-print in1 in2 inB
    set procs $in1

    foreach proc $procs {trace add execution $proc { enter leave } traceproc-print }
}


 proc intersect3 {list1 list2 inList1 inList2 inBoth} {

     upvar $inList1 in1
     upvar $inList2 in2
     upvar $inBoth  inB

     set in1 [list]
     set in2 [list]
     set inB [list]
 
     set list1 [lsort $list1]
     set list2 [lsort $list2]

     # Shortcut for identical lists is faster
     if { $list1 == $list2 } {   
         set inB $list1
     } else {
         set i 0
         foreach element $list1 {
             if {[set p [lsearch [lrange $list2 $i end] $element]] == -1} {
                 lappend in1 $element
             } else {
                 if { $p > 0 } {
                     set e [expr {$i + $p -1}]
                     foreach entry [lrange $list2 $i $e] {
                         lappend in2 $entry
                     }
                     incr i $p
                 }
                 incr i
                 lappend inB $element
             }
         }
         foreach entry [lrange $list2 $i end] {
             lappend in2 $entry
         }
     }
 } ;# David Easton
