# In the line of http://wiki.tcl.tk/1234
#
namespace eval 3d {
  proc identity {} {list 1 0 0   0 1 0   0 0 1   0 0 0}
  proc translate {dx dy dz} {list 1 0 0 0 1 0 0 0 1 $dx $dy $dz}
  proc scale {sx { sy {}} {sz {}} } {
      if { $sy eq {} } { set sy $sx }
      if { $sz eq {} } { set sz $sx }

      list $sx 0 0 0 $sy 0 0 0 $sz 0 0 0
  }
  set ::pi [expr {atan(1)*4}]
  proc rotate {axis angle {units radians}} {
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
     switch $axis {
      x - X {
	set reply \
	  [list	 1 0 0 						\
		 0 [expr { cos($angle)}] [expr {-sin($angle)}] 	\
		 0 [expr { sin($angle)}] [expr { cos($angle)}] 	\
		 0 0 0]
      }
      y - Y {
	set reply \
	  [list	[expr { cos($angle)}] 0 [expr { sin($angle)}]	\
		0 1 0						\
		[expr {-sin($angle)}] 0 [expr { cos($angle)}]	\
		0 0 0]
      }
      z - Z {
	set reply \
	  [list	[expr { cos($angle)}] [expr {-sin($angle)}] 0 	\
		[expr { sin($angle)}] [expr { cos($angle)}] 0 	\
		0 0 1						\
		0 0 0]
      }
     }

     set reply
  }

  proc transform {transform args} {
     if {[llength $args]==1} {set args [lindex $args 0]}
     set result [list]
     foreach {a b c d e f h i j k l m} $transform {break}
     foreach {x y z} $args {
        lappend result  [expr {$a*$x+$b*$y+$c*$z+$k}]	\
	    		[expr {$d*$x+$e*$y+$f*$z+$l}]	\
	    		[expr {$h*$x+$i*$y+$j*$z+$m}]
     }
     return $result
  }

  proc transforms {transform args} {							
     foreach {a b c d e f h i j k l m} $transform {break}		; # a d h k		o r u x	
     foreach xform $args {						; # b e i l 	*	p s v y	 
        foreach {o p q   r s t   u v w   x y z} $xform {break}		; # c f j m		q t w z	
        foreach {a b c   d e f   h i j   k l m} [list 					\
               [expr {$a*$o+$d*$p+$h*$q}]	[expr {$b*$o+$e*$p+$i*$q}]	[expr {$c*$o+$f*$p+$j*$q}]	\
               [expr {$a*$r+$d*$s+$h*$t}]	[expr {$b*$r+$e*$s+$i*$t}]	[expr {$c*$r+$f*$s+$j*$t}]	\
               [expr {$a*$u+$d*$v+$h*$w}]	[expr {$b*$u+$e*$v+$i*$w}]	[expr {$c*$u+$f*$v+$j*$w}]	\
               [expr {$a*$x+$d*$y+$h*$z+$k}] 	[expr {$b*$x+$e*$y+$i*$z+$l}]	[expr {$c*$x+$f*$y+$j*$z+$m}]	\
	       ] {break}
     }
     list $a $b $c $d $e $f $h $i $j $k $l $m
  }

  proc inverse { transform } {				  # http://tog.acm.org/resources/GraphicsGems/gemsii/inverse.c
     set PRECISION_LIMIT 1.0e-15			; #
     foreach {m00 m10 m20    m01 m11 m21    m02 m12 m22    m30 m31 m32} $transform {break}


     # Calculate the determinant of submatrix A and determine if the
     # the matrix is singular as limited by the double precision
     # floating-point data representation.
     #
     set pos 0.0
     set neg 0.0

     set temp [expr { $m00 * $m11 * $m22 }];   if { $temp >= 0.0 } { set pos [expr { $pos+$temp }] } else { set neg [expr { $neg+$temp }] }
     set temp [expr { $m01 * $m12 * $m20 }];   if { $temp >= 0.0 } { set pos [expr { $pos+$temp }] } else { set neg [expr { $neg+$temp }] }
     set temp [expr { $m02 * $m10 * $m21 }];   if { $temp >= 0.0 } { set pos [expr { $pos+$temp }] } else { set neg [expr { $neg+$temp }] }
     set temp [expr {-$m02 * $m11 * $m20 }];   if { $temp >= 0.0 } { set pos [expr { $pos+$temp }] } else { set neg [expr { $neg+$temp }] }
     set temp [expr {-$m01 * $m10 * $m22 }];   if { $temp >= 0.0 } { set pos [expr { $pos+$temp }] } else { set neg [expr { $neg+$temp }] }
     set temp [expr {-$m00 * $m12 * $m21 }];   if { $temp >= 0.0 } { set pos [expr { $pos+$temp }] } else { set neg [expr { $neg+$temp }] }

     set det_1 [expr { $pos+$neg }]

     # Is the submatrix A singular?
     #
     if { ($det_1 == 0.0) || (abs($det_1 / ($pos - $neg)) < $PRECISION_LIMIT) } {
	 return [list 0 0 0   0 0 0   0 0 0   0 0 0]
     }

     # Calculate inverse(A) = adj(A) / det(A)
     #
     set det_1 [expr { 1.0 / $det_1 }]

     set x00 [expr { ( $m11 * $m22 - $m12 * $m21 ) * $det_1 }]
     set x10 [expr {-( $m10 * $m22 - $m12 * $m20 ) * $det_1 }]
     set x20 [expr { ( $m10 * $m21 - $m11 * $m20 ) * $det_1 }]
     set x01 [expr {-( $m01 * $m22 - $m02 * $m21 ) * $det_1 }]
     set x11 [expr { ( $m00 * $m22 - $m02 * $m20 ) * $det_1 }]
     set x21 [expr {-( $m00 * $m21 - $m01 * $m20 ) * $det_1 }]
     set x02 [expr { ( $m01 * $m12 - $m02 * $m11 ) * $det_1 }]
     set x12 [expr {-( $m00 * $m12 - $m02 * $m10 ) * $det_1 }]
     set x22 [expr { ( $m00 * $m11 - $m01 * $m10 ) * $det_1 }]


     # Calculate -C * inverse(A) 
     #
     set x30 [expr {-( $m30 * $x00 + $m31 * $x10 + $m32 * $x20 ) }]
     set x31 [expr {-( $m30 * $x01 + $m31 * $x11 + $m32 * $x21 ) }]
     set x32 [expr {-( $m30 * $x02 + $m31 * $x12 + $m32 * $x22 ) }]

     list $x00 $x10 $x20    $x01 $x11 $x21    $x02 $x12 $x22    $x30 $x31 $x32
  }
}

