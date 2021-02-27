
 # Stack Ops
 #
 proc lpush { S x } { upvar $S s; lappend s $x }                                               
 proc lpop  { S   } { upvar $S s; lindex [list [lindex $s end] [set s [lrange $s 0 end-1]]] 0 } 
