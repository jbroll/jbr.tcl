proc svg-line2 {p0 p1 dist} {
    lassign $p0 x0 y0
    lassign $p1 x1 y1

    set dx [expr {$x1 - $x0}]
    set dy [expr {$y1 - $y0}]
    set len [expr {sqrt($dx*$dx + $dy*$dy)}]

    if {$len == 0} {
        # Degenerate: points coincide
        return [list $x0 $y0 $x1 $y1]
    }

    # Unit vector from p0 to p1
    set ux [expr {$dx / $len}]
    set uy [expr {$dy / $len}]

    # Step back from p1 by dist
    set x2 [expr {$x1 - $ux * $dist}]
    set y2 [expr {$y1 - $uy * $dist}]

    return [list $x2 $y2]
}

proc arrowhead {coords width stroke arrowshape} {
    lassign $coords x0 y0 x1 y1
    lassign $arrowshape len wid stem

    # Defaults
    if {$len eq ""} { set len 8 }
    if {$wid eq ""} { set wid 10 }
    if {$stem eq ""} { set stem $width }

    # Optionally scale arrow relative to line width
    set len_scaled [expr {$len + $width - 1}]
    set wid_scaled [expr {$wid + $width - 1}]
    set half [expr {$wid_scaled / 2.0}]

    # Unit vector along the segment
    set dx [expr {$x1 - $x0}]
    set dy [expr {$y1 - $y0}]
    set dist [expr {sqrt($dx*$dx + $dy*$dy)}]
    if {$dist == 0} { return "" }  ;# degenerate

    set ux [expr {$dx / $dist}]
    set uy [expr {$dy / $dist}]

    # Perpendicular vector for width
    set px [expr {-$uy * $half}]
    set py [expr {$ux * $half}]

    # Tip is at the endpoint
    set tipx $x1
    set tipy $y1

    # Base corners of the arrow
    set base1x [expr {$x1 - $len_scaled*$ux + $px}]
    set base1y [expr {$y1 - $len_scaled*$uy + $py}]
    set base2x [expr {$x1 - $len_scaled*$ux - $px}]
    set base2y [expr {$y1 - $len_scaled*$uy - $py}]

    # Return the SVG polygon element
    return "  <polygon points=\"$tipx,$tipy $base1x,$base1y $base2x,$base2y\" fill=\"$stroke\" />\n"
}



proc canvas_to_svg {c {viewtag viewbox}} {
    # --- ViewBox from the "viewbox" tag (fallback to canvas size) ---
    set bbox [$c bbox $viewtag]
    if {$bbox eq ""} {
        set x0 0; set y0 0
        set w [$c cget -width]
        set h [$c cget -height]
    } else {
        lassign $bbox x0 y0 x1 y1
        set w [expr {$x1 - $x0}]
        set h [expr {$y1 - $y0}]
    }
    set header "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$h\" height=\"$h\" viewBox=\"$x0 $y0 $w $h\">\n"

    # Buckets
    set defs   ""
    set shapes ""

    # Background (use viewport percentages so it always covers the visible area)
    set bg [$c cget -background]
    if {$bg eq ""} { set bg white }

    # ---- Helper: build "x,y x,y ..." from coords ----
    proc ::_pts {coords} {
        set out ""
        foreach {x y} $coords { append out "$x,$y " }
        string trim $out
    }

    # ---- Helper: map Tk capstyle -> SVG linecap ----
    proc ::_cap {tkcap} {
        switch -- $tkcap {
            butt        { return butt }
            round       { return round }
            projecting  { return square }  ;# Tk "projecting" == SVG "square"
            default     { return butt }
        }
    }

    # ---- Walk items and emit shapes/defs ----
    foreach id [$c find all] {
        set type   [$c type $id]
        set coords [$c coords $id]

        switch -- $type {
            line {
                set stroke [$c itemcget $id -fill]
                if {$stroke eq ""} { set stroke black }
                set width  [$c itemcget $id -width]
                if {$width eq ""} { set width 1 }
                set cap    [::_cap [$c itemcget $id -capstyle]]

                set arrow  [$c itemcget $id -arrow]         ;# none|first|last|both
                set ashape [$c itemcget $id -arrowshape]     ;# "len wid stem"
                lassign $ashape len wid stem

                if {$arrow ne "none"} {
                    if {$arrow eq "first" || $arrow eq "both"} {
                        append shapes [arrowhead [lrange $coords 0 3] $width $stroke $ashape]
                        set p0 [svg-line2 [lrange $coords 0 1] [lrange $coords 2 3] $len]
                        set coords [lreplace $coords 0 1 {*}$p0]
                    }
                    if {$arrow eq "last"  || $arrow eq "both"} {
                        append shapes [arrowhead [lrange $coords end-3 end] $width $stroke $ashape]
                        set pN [svg-line2 [lrange $coords end-3 end-2] [lrange $coords end-1 end] $len]
                        set coords [lreplace $coords end-1 end {*}$pN]
                    }
                }

                # Polyline points
                set pts [::_pts $coords]
                append shapes "  <polyline points=\"$pts\" fill=\"none\" stroke=\"$stroke\" stroke-width=\"$width\" stroke-linecap=\"$cap\" />\n"
            }

            polygon {
                set fill    [$c itemcget $id -fill]
                set outline [$c itemcget $id -outline]
                set width   [$c itemcget $id -width]
                if {$width eq ""} { set width 1 }

                # Map empty to none (valid SVG) and avoid empty attributes
                if {$fill eq ""}    { set fill    none }
                if {$outline eq ""} { set outline none }

                set pts [::_pts $coords]
                append shapes "  <polygon points=\"$pts\" fill=\"$fill\" stroke=\"$outline\" stroke-width=\"$width\" />\n"
            }

            oval {
                lassign $coords x0 y0 x1 y1
                set fill    [$c itemcget $id -fill]
                set outline [$c itemcget $id -outline]
                set width   [$c itemcget $id -width]
                if {$width eq ""} { set width 1 }
                if {$fill eq ""}    { set fill    none }
                if {$outline eq ""} { set outline none }

                set cx [expr {($x0+$x1)/2.0}]
                set cy [expr {($y0+$y1)/2.0}]
                set rx [expr {abs($x1-$x0)/2.0}]
                set ry [expr {abs($y1-$y0)/2.0}]
                append shapes "  <ellipse cx=\"$cx\" cy=\"$cy\" rx=\"$rx\" ry=\"$ry\" fill=\"$fill\" stroke=\"$outline\" stroke-width=\"$width\" />\n"
            }

            rectangle {
                lassign $coords x0 y0 x1 y1
                set fill    [$c itemcget $id -fill]
                set outline [$c itemcget $id -outline]
                set width   [$c itemcget $id -width]
                if {$width eq ""} { set width 1 }
                if {$fill eq ""}    { set fill    none }
                if {$outline eq ""} { set outline none }

                set rw [expr {$x1 - $x0}]
                set rh [expr {$y1 - $y0}]
                append shapes "  <rect x=\"$x0\" y=\"$y0\" width=\"$rw\" height=\"$rh\" fill=\"$fill\" stroke=\"$outline\" stroke-width=\"$width\" />\n"
            }

            default {
                # ignore other types for now
            }
        }
    }

    # ---- Stitch SVG ----
    set svg  "<?xml version=\"1.0\" standalone=\"no\"?>\n"
    append svg $header
    if {$defs ne ""} {
        append svg "  <defs>\n$defs  </defs>\n"
    }
    # background that always covers viewport (percent coords)
    append svg "  <rect x=\"0\" y=\"0\" width=\"100%\" height=\"100%\" fill=\"$bg\" />\n"
    append svg $shapes
    append svg "</svg>\n"
    return $svg
}

