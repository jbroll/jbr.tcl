
source ./c39.tcl

  proc dxf::barcode { x y w h string { box 0 } } {
        set y1 [expr {$y + $h}]

        set x0 $x
        set x  [expr {$x + $w * 8}]
        dxf::solidbox  $x0 $y $x $y1
	if { $box } { dxf::box $x0 $y $x $y1 }

        foreach { bar space } [split [c39 $string] ""] {
            set x [expr {$x + $w * $bar}]

            if { $space ne {} } {
                set x0 $x
                set x  [expr {$x + $w * $space}]

                dxf::solidbox $x0 $y $x $y1

		if { $box } { dxf::box $x0 $y $x $y1 }
            }
        }
	set x0 $x
        set x  [expr {$x + $w * 8}]
        dxf::solidbox  $x0 $y $x $y1

	if { $box } { dxf::box $x0 $y $x $y1 }
  }
