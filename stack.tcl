
 # Stack Ops
 #
 proc push { S x } { upvar $S s; lappend s $x }                                               
 proc pop  { S   } { upvar $S s; lindex [list [lindex $s end] [set s [lrange $s 0 end-1]]] 0 } 
