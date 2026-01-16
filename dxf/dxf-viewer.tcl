#!/usr/bin/env tclkit8.6.1
#
 package require Tk
 source dxf-parse.tcl

    set Width  800
    set Height 800

    array set colors { red             1 yellow          2 green           3 cyan            4 blue            5
            	       magenta         6 black           7 gray            8 gray50          9 pink 0 }


    array set cnumber [join [lmap { name num } [array get colors] { list $num $name }]]

 proc I { x } { set x }

 proc Y { y } { expr { $::Height - $y } }

 proc center { x1 y1 x2 y2 } { list [expr { ($x2+$x1)/2 }] [expr { ($y2+$y1)/2 }] }
 proc range  { x1 y1 x2 y2 } { list [expr { ($x2-$x1)   }] [expr { ($y2-$y1)   }] }

 proc bb { x y rx ry } { list [expr {$x-($rx)/2.}] [expr {$y-($ry)/2.}] [expr {$x+($rx)/2.}] [expr {$y+($ry)/2.}] }
 proc color { entity } {
	if { [dict exists $entity color] } { return $::cnumber([dict get $entity color]) }

	return $::cnumber([dict get $::dxf LAYER [dict get $entity layer] color])
 }
	
 interp create -safe safe

 proc safe-proc { name args body } {
     interp alias safe $name {} $name
     proc $name $args $body
 }
	
 safe-proc SECTION { 2 name args } {
    if { $name ne "HEADER" } { return }

    set line {}

    foreach { name value } $args {
	switch $name {
	    varname { 	if { $line ne {} } { dict set ::dxf HEADER $varname $line };  set varname $value; set line {} }
	    default {	lappend line $name $value }
	}
    }
 }

 safe-proc LTYPE   { args } { }
 safe-proc LAYER   { args } { dict with args {};	dict set ::dxf LAYER $name $args }
 safe-proc LINE    { args } { dict with args {};	dict set ::dxf Entity [.drawing create line $x [Y $y] $x1 [Y $y1] -fill [color $args] -tag "layer:$layer"] $args }
 safe-proc ARC     { args } { dict with args {};	dict set ::dxf Entity [.drawing create arc  {*}[bb $x [Y $y] $dist*2 $dist*2] -start [expr {$a1}] -extent [expr {$a2-$a1}] -style arc -outline [color $args] -tag "layer:$layer"] $args }
 safe-proc CIRCLE  { args } { dict with args {};	dict set ::dxf Entity [.drawing create oval {*}[bb $x [Y $y] $dist*2 $dist*2] -outline [color $args] -tag "layer:$layer"] $args }
 safe-proc ELLIPSE { args } { dict with args {};	dict set ::dxf Entity [.drawing create oval {*}[bb $x [Y $y] $x1*2 $y1*2] -outline [color $args] -tag "layer:$layer"] $args }
 safe-proc SOLID   { args } { dict with args {}; 	dict set ::dxf Entity [.drawing create rect $x [Y $y] $x1 [Y $y1] -fill [color $args] -tag "layer:$layer"] $args }
 safe-proc TEXT    { args } { set a1 0 ; dict with args {};	dict set ::dxf Entity [.drawing create text $x [Y $y] -angle $a1 -text $text -fill [color $args] -tag "Text layer:$layer" -anchor sw] $args }

 safe-proc POLYLINE { args } { dict with args {};	set id [.drawing create line 0 0 0 0 -fill [color $args]]
     							dict set ::dxf Entity $id $args
							dict set ::dxf shape $id
							dict set ::dxf points {}
 }
 safe-proc VERTEX   { args } { dict with args {};	dict lappend ::dxf points $x $y }
 safe-proc SEQEND   { args } { dict with args {};	.drawing coords [dict get $::dxf shape] [dict get $::dxf points] }

    grid [button .open -text Open -command file-open]						\
	 [button .raise-header  -text Header  -command "w-raise .header"]			\
	 [button .raise-layer   -text Layer   -command "w-raise .layers"]			\
	 [button .raise-entity  -text Entity  -command "w-raise .entity"]			\
	 [label  .status -width 15 -justify left]						\
	 [label .coords -width 20 -justify left -font { Courier 14 }] -sticky news

    grid  [text .layers -width 40 -height 20 -bd 2 -relief ridge] - - - - \
	  [text .entity -width 40 -height 20 -bd 2 -relief ridge]     			-row 1 -sticky new
    grid [text .header] - - - - -				    			-row 1 -sticky news
    grid [canvas .drawing -width $Width -height $Height -background white] - - - - - 	-row 1 -sticky news
    focus .drawing 

    set ::dxfdir [pwd]
    proc file-open {} {
	if { [set file [tk_getOpenFile -initialdir $::dxfdir -filetypes {{ { DXF Files } { .dxf } } { { All } { * } }}]] ne {} } {
	    set ::dxfdir [file dirname $file]
	    dxf-open $file
	}
    }

    proc w-raise { w } { incr ::$w; if { [set ::$w]%2 } { raise $w } else { lower $w } }

	# Experiment with scale/move items in a canvas		# http://wiki.tcl.tk/10381
	#
	proc moveItems { x y } {
	    .drawing move all [expr {$x-$::xc}] [expr {$y-$::yc}]

	    set ::xc $x
	    set ::yc $y

	    update-scale $x $y
	}

	proc scaleItems { type x y } {
	    if { $type eq "+" } { set scale [expr { sqrt(2.0) }]
	    } else 		{ set scale [expr {1.0/sqrt(2.0)}] }

	   
	    .drawing scale all $x $y $scale $scale

	    update-scale $x $y

	    foreach text [.drawing find withtag Text] {
		set height [dict get $::dxf Entity $text dist]

		.drawing itemconfigure $text -font [list Courier [expr { -int($height/$::SX) }]]
	    }
	}

	bind .drawing <Motion>		{ show-coords %x %y }
	bind .drawing <Button-1>        { set xc %x; set yc %y;  button1 %x %y } 
	bind .drawing <B1-Motion>       { moveItems    %x %y }
	bind .drawing <KeyPress-z>      { scaleItems + $::xx $::yy }
	bind .drawing <KeyPress-x>      { scaleItems - $::xx $::yy }
 
    proc button1 { x y } {
	.entity delete 0.0 end
	catch {
	    set text [dict get $::dxf Entity [.drawing find closest $x $y]]

	    .entity insert 0.0 [join [lmap { name value } $text { I "[format %-20s $name] $value"}] \n]
	}
    }

    set TX 0								; # Keep track of the current scale transform
    set TY 0
    set SX 1
    set SY 1

    proc show-coords { x y } {						; # Show the current position
	set ::xx $x
	set ::yy $y

	.coords configure -text "Coords: [format %7.2f [expr { ($x+$::TX)*$::SX }]] [format %7.2f [Y [expr { ($y+$::TY)*$::SY }]]]"
    }

    # There is a small "fudge" factor in the canvas move/scale commands due
    # to the cavas keeping some internal values as integers.  Place come
    # fiducial items on the canvas and track the actual transformation by 
    # querying thier positions in "update-scale".
    #
    set Zero [.drawing create polygon    0    0 -tag Scale -state hidden]
    set 1000 [.drawing create polygon 1000 1000 -tag Scale -state hidden]

    proc update-scale { x y } {
	lassign [.drawing coords $::Zero] tx ty
	set ::TX [expr {-$tx}]
	set ::TY [expr {-$ty}]

	lassign [.drawing coords $::1000] sx sy
	set ::SX [expr {1000.0/($sx-$tx)}]
	set ::SY [expr {1000.0/($sy-$ty)}]

	show-coords $x $y

    }

    proc layer-toggle { layer } {
	if { [set ::layer_$layer] } {
	    .drawing itemconfigure layer:$layer -state normal
	} else {
	    .drawing itemconfigure layer:$layer -state hidden
	}
    }

    proc dxf-open { file } {
	set ::dxf {}
	.drawing delete !Scale
	.header  delete 0.0 end
	.layers  delete 0.0 end

	# Convert the dxf into an executable Tcl script and evaluate it 
	# in a safe interpreter.
	#
	interp eval safe [join [dxf-parse [cat $file] { SECTION LTYPE LAYER ARC LINE CIRCLE TEXT POLYLINE VERTEX SEQEND }] \n]

	# Center the drawing in the available canvas space
	#
	lassign [center {*}[.drawing bbox !Text]] ::xc ::yc
	lassign [range  {*}[.drawing bbox !Text]] xs ys
	set ss [expr { ($::Height/max($xs, $ys)) }]

	moveItems          [expr { $::Width/2}] [expr { $::Height/2}] 
	.drawing scale all [expr { $::Width/2}] [expr { $::Height/2}] $ss $ss
	update-scale       [expr { $::Width/2}] [expr { $::Height/2}]


	.header insert 0.0 [join [lmap { name value } [dict get $::dxf HEADER] { I "[format %-20s $name] $value"}] \n]
	.layers insert 0.0 [join [lmap { name value } [dict get $::dxf LAYER]  { I "[format %-20s $name] $value"}] \n]
	set i 1
	foreach { layer value } [dict get $::dxf LAYER] {
	    set ::layer_$layer 1
	    checkbutton .layers.layer_$layer -variable layer_$layer -command "layer-toggle $layer"
	    .layers window create $i.0 -window .layers.layer_$layer 
	    incr i
	}

	wm title . "dxf-viewer :  $file"
    }

if { [llength $argv] } { dxf-open [lindex $argv 0] }

