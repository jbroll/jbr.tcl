# http://wiki.tcl.tk/14022

 foreach op {+ - * / % ==} {proc $op {a b} "expr {\$a $op \$b}"}

 proc vec {op a { b {} } } {
     if { $b eq {} } {
         lmap i $a {$op $i}
     } elseif {[llength $a] == 1 && [llength $b] == 1} {
         $op $a $b
     } elseif {[llength $a]==1} {
         lmap i $b {vec $op $a $i}
     } elseif {[llength $b]==1} {
         lmap i $a {vec $op $i $b}
     } elseif {[llength $a] == [llength $b]} {
         set res {}
         foreach i $a j $b {lappend res [vec $op $i $j]}
         set res
     } else {error "length mismatch [llength $a] != [llength $b]"}
 }

 proc sum { args } { expr [join $a +]+0}
 proc sqr { a }    { expr { $a*$a } }
 proc dot { a b }  { sum {*}[vec * $a $b] }
 proc mag { a }    { expr { sqrt([sum [sqr [vec - $a $b]]]) } }

 proc angle { a b } {
	
 }
