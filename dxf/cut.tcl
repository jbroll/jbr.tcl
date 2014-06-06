
# Cutter library sits between the application and dxf.tcl.  It 
# allows the application of:
#
#    cut::set-transform  <2d transform>		- a geometric transform
#    cut::set-leading    <distance> <side>	- cutter lead in
#    cut::set-cuttercomp <radius>   <side>	- cutter compensation
#    cut::set-repeat     <n>			- cutter path repeat
#
namespace eval cut {
	    proc K { x y } { set x }

	    proc lrotate { list { n 1 } } {
		set n [string map [list end [expr { [llength $list]-1 }]] $n]
		set n [expr ($n) % [llength $list]]
		return [list {*}[lrange $list $n end] {*}[lrange $list 0 $n-1]]
	    }

	    proc segment-length { list } {
		    set list [lassign $list x0 y0]

		    return [lmap { x y } $list { 
				K [expr { sqrt(($x-$x0)*($x-$x0) + ($y-$y0)*($y-$y0)) }] [set x0 $x; set y0 $y]
			    }]
	    }

	    proc lmin-index { list } {
		set min 10000000
		set idx 0
		set i   0
		foreach x $list {
		    if { $x <= $min } {
			set idx $i
			set min $x
		    }
		    incr i
		}

		 return $idx
	    }

	    proc angle360 { a } {
		return $a

		while { $a <   0 } { set a [expr $a + 360] }
		while { $a > 360 } { set a [expr $a - 360] }

		return $a
	    }

	# rotate the list of polygon points so that the shortest segment is 
	# last on the list.
	#
	# 1. compute the length of each segment
	# 2. find the index of the shortest segment
	# 3. rotate the segment just past the shortest to the 
	#    front.  This makes the shortest segment last.
	#
	proc rotate-shortest-is-last { points } {
	    lappend points [lindex $points 0] [lindex $points 1]

	    lrotate [lrange $points 0 end-2] [expr { ([lmin-index [segment-length $points]]+1)*2 }] 
	}

	# Chop the last segment in half and move the new point to the front.
	#
	proc bisect-last-segment { points } {
	    lassign [lrange $points     0   1] x0 y0
	    lassign [lrange $points end-1 end] x1 y1

	    set xmid [expr { ($x0+$x1)/2.0 }]
	    set ymid [expr { ($y0+$y1)/2.0 }]

	    lappend points $xmid $ymid
	
	    return [lrotate $points end-1]
	}

	# Return a point offset from the start of a line segment by length
	# at angle angle.
	#
	proc new-point-from-segment { points length angle } {
	    lassign $points x0 y0 x1 y1

	    set angle [expr { atan2($y1-$y0, $x1-$x0)+$angle/57.2957795 }]

	    return [list [expr { $x0+$length*cos($angle) }] [expr { $y0+$length*sin($angle) }]]
	}


	proc path-offset-point { offset x0 y0 x1 y1 x2 y2 } {
	    set angle1 [expr { atan2($y1-$y0, $x1-$x0) }]	; # Angle of each line
	    set angle2 [expr { atan2($y2-$y1, $x2-$x1) }]

	    set angle [expr { ($angle2-$angle1)/2 }]		; # Angle between lines

	    set offset [expr { $offset/cos($angle) }]

	    set angle [expr { ($angle2+$angle1)/2.0 }]		; # Absolute angle between lines

	    set xnew [expr { $x1+$offset*sin($angle) }]
	    set ynew [expr { $y1-$offset*cos($angle) }]

	    return [list $xnew $ynew]
	}

	# Offset path to the right/left for cutter compensation
	#  right = +length
	#   left = -length
	#
	#  outside corner cutter arc insertion is not performed.
	#
	proc path-offset { points offset } {
	    lassign [lrange $points end-1 end] x0 y0
	    lassign [lrange $points     0   1] x1 y1

	    # Consider the points 3 at a time.  Compensating x1 y1 in each iteration.
	    #
	    foreach { x2 y2 } [lrange $points 2 end] {
		lappend reply {*}[path-offset-point $offset $x0 $y0 $x1 $y1 $x2 $y2]

		lassign [list $x1 $y1 $x2 $y2] x0 y0 x1 y1	; # Shift to next segment pair
	    }
	    lassign [lrange $points     0   1] x2 y2
	    
	    lappend reply {*}[path-offset-point $offset $x0 $y0 $x1 $y1 $x2 $y2]
	    return $reply
	}


    # Read the 2d transform stuff into the cut:: namespace
    #
    source 2d.tcl

    variable transform  [identity]
    variable tx      	0
    variable ty      	0
    variable rot      	0
    variable sx      	1
    variable sy      	1
    variable scale      1
    variable leadin     none
    variable leadlength   0.0

    variable cuttercomp none
    variable cutterrad    0.0

    variable repeats    1
    variable stack	{}

    proc push-transform { args } {
	lappend ::cut::stack 	 $::cut::transform
	set-transform [transforms {*}$args $::cut::transform] 
    }
    proc pop-transform {} {
	set ::cut::transform [K [lindex $::cut::stack end] [set ::cut::stack [lrange $::cut::stack 0 end-1]]]
    }
 
    proc set-transform  { Transform  } {
	set ::cut::transform  $Transform
	lassign [crack $Transform] ::cut::sx ::cut::sy ::cut::rot ::cut::tx ::cut::ty
	set ::cut::scale [expr { ($::cut::sx+$::cut::sy)/2.0 }]
    }
    proc set-repeat     { Repeats    } { set ::cut::repeats    $Repeats    }

    proc set-leadin	{ Length { Side right } } { 
	set ::cut::leadlength $Length
	set ::cut::leadin     $Side
    }
    proc set-cuttercomp	{ Length { Side right } } { 
	set ::cut::cutterrad  $Length
	set ::cut::cuttercomp $Side
    }

    proc repeat { args } { join [lmap x [lrepeat $::cut::repeats x] { {*}$args }] }

    proc line { args } {
	dxf::line {*}[transform $::cut::transform {*}$args]
    }
    proc circ { x y r } { 
	repeat dxf::circ {*}[transform $::cut::transform $x $y] [expr { $r*$::cut::scale }]
    }
    proc arc { x y r start end } {
	dxf::arc {*}[transform $::cut::transform $x $y] [expr { $r*$::cut::scale }] [angle360 [expr $start+$::cut::rot]] [angle360 [expr $end+$::cut::rot]]
    }

    proc rect { x y w h { t 0 } { o 0 } } {
            set sin_t [expr sin($t * (3.14159265358979323846 * 2 / 360))]
            set cos_t [expr cos($t * (3.14159265358979323846 * 2 / 360))]


        set wdx [expr { $w / 2.0 * $cos_t }]
        set wdy [expr { $w / 2.0 * $sin_t }]
        set hdx [expr { $h / 2.0 * $sin_t }]
        set hdy [expr { $h / 2.0 * $cos_t }]
        set odx [expr { $o     * $sin_t }]
        set ody [expr { $o     * $cos_t }]

        set x1 [expr { $x - $wdx - $hdx - $odx }]
        set y1 [expr { $y - $wdy + $hdy - $ody }]
        set x2 [expr { $x - $wdx + $hdx + $odx }]
        set y2 [expr { $y - $wdy - $hdy + $ody }]

        set x3 [expr { $x + $wdx + $hdx + $odx }]
        set y3 [expr { $y + $wdy - $hdy + $ody }]
        set x4 [expr { $x + $wdx - $hdx - $odx }]
        set y4 [expr { $y + $wdy + $hdy - $ody }]

        polygon $x1 $y1 $x2 $y2 $x3 $y3 $x4 $y4
    }
    proc text { x y text height { r 0 } } {
	dxf::text {*}[transform $::cut::transform $x $y] $text [expr $::cut::scale*$height] [expr $::cut::rot*57.2957795+$r]
    }

    proc polygon { args } {
	set first  {}
	set points [lmap x $args { expr $x }]

	set leadin 0

	# Transform the points to machine coords + Add repeats
	#
	set points [join [lrepeat $::cut::repeats [transform $::cut::transform {*}$points]]]

	if { $::cut::leadin ne "none" } {
	    switch $::cut::leadin {
	     left  { set leadin [expr { $::cut::leadlength* 1 }] }
	     right { set leadin [expr { $::cut::leadlength*-1 }] }
	     default {
		error "unrecognised value for lead : $::cut::leadin"
	     }
	    }

	    set points [rotate-shortest-is-last $points]
	    set points [bisect-last-segment     $points]
	} 

	if { $::cut::cuttercomp ne "none" } {
	    switch $::cut::cuttercomp {
	     left  { set length [expr { $::cut::cutterrad*-1 }] }
	     right { set length [expr { $::cut::cutterrad* 1 }] }
	     default {
		error "unrecognised value for cutter comp : $::cut::cuttercomp"
	     }
	    }

	    set points [path-offset $points $length]
	}

	# Copy the first point last to make a polyline.
	#
	lappend points [lindex $points 0] [lindex $points 1]

	# Compute the leadin point before possible cutter comp.
	#
	if { $leadin } { set first  [new-point-from-segment  $points $leadin 90] }


        dxf::polyline {*}$first {*}$points
    }
}

