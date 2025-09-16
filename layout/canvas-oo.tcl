
package require Tk

proc   K { x y } { set x } 	; # This is just for fun.


# Create procs in the objects namespace that forward calls to instance methods.  This
# allows methods to be called without [self] or [my].
#
proc procs args {
    foreach proc $args {
        proc [uplevel 1 { namespace current }]::$proc args [subst { tailcall my $proc {*}\$args }]
    }
}

# An object that controls a set of shapes drawn on a canvas.  The shapes each
# have a coordinate system within which other objects may be draw.  Each
# coodinate system has a stacked linear tranform to control its origin,
# rotation and scale.
#
oo::class create canvas-oo {
    variable c C
    
    constructor { canvas { Tr {} } } {
        procs erase rmov amov size coords draw line poly rect oval arc ngon text csys canv image
        
        set c $canvas
        set C(,tr) [2d::transforms [2d::scale 1 -1]	\
                [2d::translate [expr [$c cget -width]/2.0] [expr [$c cget -height]/2.0]] {*}$Tr]
        
        set C(,rt)   0
        set C(,lst) {}
        set C(stk)  {}
    }
    
    method erase { id { in + } } {
        set id [my tag $id]
        
        $c delete $id
        foreach id $C($id,lst) { erase $id - }
        
        if { $in eq "+" } { 	  # http://wiki.tcl.tk/15659 Wow!
            set C($C($id,in),lst) [lsearch -all -inline -not -exact $C($C($id,in),lst) $id]
        }
        array unset C($id,*)
    }
    
    method rmov { id dx dy { dr 0 } } {
        set id [my tag $id]
        
        foreach { type x y r } [set C($id,pos)] break
        foreach {      x y r } [list [expr $x+$dx] [expr $y+$dy] [expr $r+$dr]] break
        
        amov $id $x $y $r
    }
    
    method amov { id x y { r - } { csys - } } {
        
        set id [my tag $id]
        
        foreach { type x0 y0 r0 } $C($id,pos) break
        
        if { $x eq "-" } { set x $x0 }
        if { $y eq "-" } { set y $y0 }
        if { $r eq "-" } { set r $r0 }
        
        if { $csys ne "-" && $csys ne $C($id,in) } {	# Move the shape to a new csys
            set in $C($id,in)
            set indx [lsearch $C($in,lst) $id]
            set C($in,lst) [lreplace $C($in,lst) $indx $indx]
            
            lappend  C($csys,lst) $id
            
            set C($id,in) $csys
            set nin $C($id,in)
        }
        
        set C($id,pos) [list $type $x $y $r]
        set C($id,tr)  [2d::transforms [2d::rotate $r d] [2d::scale {*}$C($id,sc)] [2d::translate $x $y] $C($C($id,in),tr)]
        set C($id,rt)  [expr $r + $C($C($id,in),rt)]
        set C($id,ok)  0
        
        foreach id $C($id,lst) { rmov $id 0 0 0 }
    }
    
    method size { id rx ry } {
        set id [my tag $id]
        
        if { $args eq {} } {
            return $C($id,xy)
        } else {
            set C($id,xy) [$C($id,ex) $rx $ry {*}$C($id,A)]
        }
        rmov $id 0 0 0
    }
    
    method coords { id args } {
        set id [my tag $id]
        
        if { $args eq {} } {
            return [set C($id,xy)]
        } else {
            set C($id,xy) $args
        }
        rmov $id 0 0 0
    }
    
    
    method draw { { id {} } } {
        
        set id [my tag $id]
        
        if { [info exists C($id,pos)] && !$C($id,ok) } {
            set type [lindex $C($id,pos) 0]
            set tr $C($id,tr)
            set xy $C($id,xy)
            
            switch $type {
                line -
                poly { $c coords $id [2d::transform $tr $xy] }
                oval {
                    set ex $C($id,ex)
                    set sc $C($id,sc)
                    set rx $C($id,rx)
                    set ry $C($id,rx)
                    set  A $C($id,A)
                    
                    set sx [expr sqrt([lindex $tr 0]*[lindex $tr 0]+[lindex $tr 1]*[lindex $tr 1])]
                    set xy [my $ex [expr $rx*$sx] [expr $ry*$sx] {*}$A]
                    
                    $c coords $id [2d::transform [2d::translate [lindex $tr 4] [lindex $tr 5]] $xy]
                }
                text {
                    $c coords $id [2d::transform $tr $xy]
                    
                    if { [info exists C($id,-rmode)] } {
                        switch $C($id,-rmode) {
                            no     { set rt 0 }
                            yes    { set rt [lindex $C($id,pos) 3] }
                            tot    { set rt $C($id,rt) }
                            -total  { set rt [expr { -($C($id,rt)) }]  }
                            -parent { set rt [expr { -(-($C($C($id,in),rt)) + [lindex $C($id,pos) 3]) }] }
                            total  { set rt $C($id,rt) }
                            parent { set rt [expr -($C($C($id,in),rt)) + [lindex $C($id,pos) 3]] }
                            default { error "invalid -rmode : $C($id,-rmode)" }
                        }
                        $c itemconfigure $id -angle $rt
                    }
                }
            }
        }
        
        foreach id $C($id,lst) { draw $id }
    }
    
    method bb { rx ry } { list [expr -($rx)/2.] [expr -($ry)/2.] [expr +($rx)/2.] [expr +($ry)/2.] }  ; # Bounding Box
    method rp { x y args } { ::polygon 0 0 [expr $x/2.0] [expr $y/2.0] {*}$args }				      ; # Regular polygon
    method xy { x y args } { list $x $y }								 	                          ; # return pair
    method xx { x y args } { return  $x }									                          ; # return x
    method rt { rx ry args } {											                              ; # Rectangle
        foreach { x0 y0 x1 y1 } [my bb $rx $ry] break

        if { $args eq "" } {
            list $x0 $y0 $x1 $y0 $x1 $y1 $x0 $y1
        } else {
            ::rndrect $x0 $y0 $x1 $y1 {*}$args 
        }
    }
    
    method tag  { tag } {							; # Look up a tag and return as canvas id
        if { ![info exists C($tag,lst)] } {
            if { [set t [$c find withtag $tag]] eq {} } {
                error "no tag $tag"
            } else {
                set tag $t
            }
        }
        
        return $tag
    }
    
    # Define the various shapes that can be drawn in the canvas.
    #
    method line   { coords args }     { my item line   {}  xx {}  0  0 $coords {} {*}$args }
    method poly   { x y coords args } { my item poly   {}  xx {} $x $y $coords {} {*}$args }
    method rect   { args }            { my item poly   {}  rt { -rnd -steps } {*}$args }
    method oval   { args }            { my item oval   {}  bb {} {*}$args }
    method arc    { args }            { my item arc    {}  bb {} {*}$args }
    method ngon   { args }            { my item poly   {}  rp { -sides -start -extent } {*}$args }
    method text   { x y text args }   { my item text   {}  xy { -rmode } $x $y 0 0 -text $text {*}$args }
    method csys   { x y id   args }   { my item csys   {}  {} {} $x $y $id 0 {*}$args }
    method window { x y w h id args } { my item window $id xy { -anchor } $x $y $w $h {*}$args }
    method image  { x y image args }   { my item image  $image xy { -width -height } $x $y 0 0 {*}$args }
    
    # Core drawing method.  Only called from a shape method above
    #
    method item { type wid expn opts x y rx ry args } {

        foreach A  {} B {} r 0 in {} sc { { 1 1 } } body {} break

        if { [llength $args] % 2 } {
            set body [lindex $args end]
            set args [lrange $args 0 end-1]
        }
        
        foreach { name value } $args {
            switch -- $name {
                -in       { set in [my tag $value] }
                -rot	  { set r  $value }
                -scale    {
                    if { [llength $value] == 1 } {
                        set sc [list $value $value]
                    } else {
                        set sc $value
                    }
                }
                default   {
                    if { $name in $opts } { lappend A  $name $value
                    } else { 		        lappend B  $name $value }
                }
            }
        }
        
        if { $in eq {} } { set in [lindex $C(stk) end] }
        
        set tx [2d::transforms [2d::rotate $r d] [2d::scale {*}$sc] [2d::translate $x $y] $C($in,tr)]
        
        switch -- $type {
            csys {
                set xy {}
                set id $rx
            }
            oval    {
                set sx [expr { sqrt([lindex $tx 0]*[lindex $tx 0]+[lindex $tx 1]*[lindex $tx 1]) }]
                set xy [my $expn [expr { $rx*$sx }] [expr { $ry*$sx }] {*}$A]
                set id [$c create $type [2d::transform [2d::translate [lindex $tx 4] [lindex $tx 5]] $xy] {*}$B]
            }
            image {
                set -width ""
                set -height ""
                foreach {k v} $args { set $k $v }

                set photo [::image create photo -file $wid]

                # Get actual size
                #
                set imgW [::image width $photo]
                set imgH [::image height $photo]

                if { ${-width}  eq "" } { set -width $imgW }
                if { ${-height} eq "" } { set -height $imgH }

                if { ${-width} != $imgW || ${-height} != $imgH } {
                    set resized [::image create photo -width ${-width} -height ${-height}]
                    puts "$resized copy $photo -from 0 0 $imgW $imgH -to 0 0 [expr {${-width}-1}] [expr {${-height}-1}]"
                    $resized copy $photo -from 0 0 $imgW $imgH -to 0 0 [expr {${-width}-1}] [expr {${-height}-1}]
                    rename $photo {}
                    set photo $resized
                }

                set sx [expr sqrt([lindex $tx 0]*[lindex $tx 0]+[lindex $tx 1]*[lindex $tx 1])]
                set xy [my $expn [expr $rx*$sx] [expr $ry*$sx] {*}$A]
                set id [$c create $type [2d::transform $tx {*}$xy] -image $photo {*}$B]
            }
            window {
                set sx [expr sqrt([lindex $tx 0]*[lindex $tx 0]+[lindex $tx 1]*[lindex $tx 1])]
                set xy [my $expn [expr $rx*$sx] [expr $ry*$sx] {*}$A]
                
                lappend B -width [lindex $xy 0] -height [lindex $xy 1]
                
                canvas-msg create $wid [canvas $c.$wid {*}$B]
                
                lappend A -window $c.$wid
                
                set xy [my $expn $x $y]
                set id [$c create $type [2d::transform $tx {*}$xy] {*}$B]
            }
            default {
                set xy [my $expn $rx $ry {*}$A]
                set id [$c create $type [2d::transform $tx {*}$xy] {*}$B]
                foreach { name value } $A { set C($id,$name) $value }
            }
        }
        switch $type {
            text { $c itemconfigure $id -angle $r }
        }
        
        set C($id,pos) [list $type $x $y $r]
        set C($id,lst)  {}
        set C($id,xy)  $xy
        set C($id,x)   $x
        set C($id,y)   $y
        set C($id,rx)  $rx
        set C($id,ry)  $ry
        set C($id,in)  $in
        set C($id,tr)  $tx
        set C($id,sc)  $sc
        set C($id,ok)    0
        set C($id,ex)  $expn
        set C($id,A)   $A
        set C($id,rt)  [expr $r + $C($C($id,in),rt)]
        
        lappend C($in,lst) $id
        
        foreach { name value } $A { set C($id,$name) $value }
        
        if { $body ne {} } {
            switch $type {
                window {
                    set path [uplevel 2  { namespace path }]
                    
                    uplevel 2 [list namespace path [list [namespace current] {*}$path]]
                    uplevel 2 [list $wid csys 0 0 page $body]
                    uplevel 2 [list namespace path [list {*}$path]]
                }
                default {
                    lappend C(stk) $id
                    
                    set path [uplevel 2  { namespace path }]
                    
                    uplevel 2 [list namespace path [list [namespace current] {*}$path]]
                    uplevel 2 $body
                    uplevel 2 [list namespace path [list {*}$path]]
                    
                    set C(stk) [K [lrange $C(stk) 0 end-1] [set $C(stk) {}]]
                }
            }
        }
        
        my draw $id
        return $id
    }
}


