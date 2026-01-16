# dxf.tcl: routines to write out the group code/value pairs for elements in a .dxf file
#
# Handy web site explaining DXF file format and group codes: 
#
# http://www.autodesk.com/techpubs/autocad/acadr14/dxf/dxf_group_codes.htm
#
 namespace eval dxf {
     
        variable colors
        variable ltype 0
        variable layer 0
        variable file


    array set colors {
            red             1
            yellow          2
            green           3
            cyan            4
            blue            5
            magenta         6
            black           7
            gray            8
            lt-gray         9
    }

    proc code { args } {
        variable file
        foreach { code value } $args { puts $file "[format %3d $code]\n$value" }
    }

    proc write { f body } {
            variable file $f

        uplevel $body
        code 0 EOF
    }

    proc section { name body } {
        code 0 SECTION 2 $name
        uplevel $body
        code 0 ENDSEC
    }

    proc table { type max body } {
        code 0 TABLE 2 $type 70 $max 
        uplevel $body
        code 0 ENDTAB
    }

    proc ltype { name { flags 0 } } {
        code  0 LTYPE 2 $name
	code 70 $flags 3 $name 72 65 73 0 40 0.0000
    }

    proc layer { { name 0 } { flags 0 } { color black } { ltype 0 } } {
        set color $::dxf::colors($color)

        code  0 LAYER 2 $name 
	code 70 $flags 6 $ltype 62 $color
    }

    proc set-layer { l } { variable layer $l }

    proc set-ltype { l } { variable ltype; set ltype $l }

    proc item { item args } {
        variable layer
        variable ltype

        code 0 $item 8 $layer 6 $ltype {*}$args
    }


    proc line { x1 y1 x2 y2		  } { item LINE   10 $x1 20 $y1 11 $x2 21 $y2 }
    proc text { x y text { height .5 }	r } { item TEXT   10 $x  20 $y  40 $height 50 $r 1 $text }
    proc circ { x y r 			  } { item CIRCLE 10 $x  20 $y  40 $r }
    proc arc  { x y r a1 a2		  } { item ARC    10 $x  20 $y  40 $r 50 $a1 51 $a2 }

    proc solid { x1 y1 x2 y2 x3 y3 x4 y4  } {
 	foreach { x1 y1 x2 y2 x3 y3 x4 y4 } [transform $::dxf::transform $x1 $y1 $x2 $y2 $x3 $y3 $x4 $y4] break
        item SOLID 10 $x1 20 $y1 11 $x2 21 $y2
	code 12 $x4 22 $y4
	code 13 $x3 23 $y3
    }

    proc solidbox  { x1 y1 x2 y2 { color 256 } } {
        solid $x1 $y1 $x1 $y2 $x2 $y2 $x2 $y1
    }

    proc polyline { args } {
	set x0 [lindex $args 0]
	set y0 [lindex $args 1]

	foreach { x y } [lrange $args 2 end] {
	    #puts "polyline: drawing segment from $x0 $y0 to $x $y"
	    line $x0 $y0 $x $y
	    set x0 $x
	    set y0 $y
	}
    }

    proc polygon { args } {

	# args is the set of unique vertices of the polygon, 
	# beginning with the starting point. Append this starting 
	# point to the list going to polyline, so it can 
	# become the end point of the polygon and the last 
	# segment will be drawn.

	polyline {*}$args [lindex $args 0] [lindex $args 1]
    }

    proc box  { x1 y1 x2 y2 } {
        polygon $x1 $y1 $x1 $y2 $x2 $y2 $x2 $y1
    }

    proc rect { x y w h { t 0 } { o 0 } } {
            set sin_t [expr {sin($t * (3.14159265358979323846 * 2 / 360))}]
            set cos_t [expr {cos($t * (3.14159265358979323846 * 2 / 360))}]


        set wdx [expr {$w / 2.0 * $cos_t}]
        set wdy [expr {$w / 2.0 * $sin_t}]
        set hdx [expr {$h / 2.0 * $sin_t}]
        set hdy [expr {$h / 2.0 * $cos_t}]
        set odx [expr {$o     * $sin_t}]
        set ody [expr {$o     * $cos_t}]

        set x1 [expr {$x - $wdx - $hdx - $odx}]
        set y1 [expr {$y - $wdy + $hdy - $ody}]
        set x2 [expr {$x - $wdx + $hdx + $odx}]
        set y2 [expr {$y - $wdy - $hdy + $ody}]

        set x3 [expr {$x + $wdx + $hdx + $odx}]
        set y3 [expr {$y + $wdy - $hdy + $ody}]
        set x4 [expr {$x + $wdx - $hdx - $odx}]
        set y4 [expr {$y + $wdy + $hdy - $ody}]

        polygon $x1 $y1 $x2 $y2 $x3 $y3 $x4 $y4
    }
 }
