# Taken from http://wiki.tcl.tk/1234
#
namespace eval 2d { 
  proc identity {} {list 1 0 0 1 0 0}
  proc translate {dx dy} {list 1 0 0 1 $dx $dy}
  proc reflect-x {} {list 1 0 0 -1 0 0}
  proc reflect-y {} {list -1 0 0 1 0 0}
  proc shear {sx sy} {list 1 $sx $sy 1 0 0}
  proc scale {sx { sy - } } {if { $sy == "-" } { set sy $sx }; list $sx 0 0 $sy 0 0}
  set ::pi [expr {atan(1)*4}]
  proc rotate {angle {units radians}} {
     global pi
     switch -- $units {
        d - de - deg - degr - degre - degree - degrees {
            set angle [expr {double($angle)/180*$pi}]
        }
        g - gr - gra - grad - gradi - gradie - gradien -
        gradient - gradients { # I think I've spelt this one right...
            set angle [expr {double($angle)/200*$pi}]
        }
        r - ra - rad - radi - radia - radian - radians {
           # Do nothing
        }
        default {
           return -code error "unknown angle unit \"$units\": must be\
                   one of degrees, gradients or radians"
        }
     }
     list [expr {cos($angle)}] [expr {sin($angle)}] \
             [expr {-sin($angle)}] [expr {cos($angle)}] 0 0
  }

  proc transform {transform args} {
     if {[llength $args]==1} {set args [lindex $args 0]}
     set result [list]
     foreach {a b c d e f} $transform {break}
     foreach {x y} $args {
        lappend result [expr {$a*$x+$b*$y+$e}] [expr {$c*$x+$d*$y+$f}]
     }
     return $result
  }

  proc transforms {transform args} {
     foreach {a b c d e f} $transform {break}
     foreach xform $args {
        foreach {i j k l m n} $xform {break}
        # Next line does simultaneous assignment...
        foreach {a b c d e f} [list \
               [expr {$a*$i+$c*$j}]    [expr {$b*$i+$d*$j}] \
               [expr {$a*$k+$c*$l}]    [expr {$b*$k+$d*$l}] \
               [expr {$e*$i+$f*$j+$m}] [expr {$e*$k+$f*$l+$n}]] {break}
     }
     list $a $b $c $d $e $f
  }

  proc inverse { transform } {
     foreach {a b c d e f} $transform {break}

    set pos [expr $a * $d]
    set neg [expr $b * $c]
    set det [expr $pos - $neg]

    if { ( $det == 0.0) || (abs( $det / ($pos - $neg)) < 10e-15) } {
	error "singular matrix"
    }

    foreach { a b c d } [list 						\
	[expr   $d  / double($det)]	[expr -($b) / double($det)]	\
	[expr -($c) / double($det)]	[expr   $a  / double($det)]] break
    foreach { e f } [list 						\
        [expr -( $e * $a + $f * $b )]   [expr -( $e * $c + $f * $d )]] break

    list $a $b $c $d $e $f
  }

  proc crack { transform } {
    foreach {a b c d e f} $transform {break}
    set sign_a [expr { $a >= 0 ? 1 : -1 }]
    set sign_d [expr { $d >= 0 ? 1 : -1 }]

    set sx [expr { $sign_a * sqrt($a*$a+$b*$b) }]
    set sy [expr { $sign_d * sqrt($c*$c+$d*$d) }]
    set  r [expr { atan2(-($b), $a) }]

    return [list $sx $sy $r $e $f]
  }

}
