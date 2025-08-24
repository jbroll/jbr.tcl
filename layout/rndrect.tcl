# Draw a rounded rectangle as a polygon
#
proc rndrect {x1 y1 x2 y2 args } {
    set rnd 4
    set steps 16
    foreach { opt value } $args {
        switch $opt {
            -rnd { set r $value }
            -steps { set steps $value }
            default {
                error "unknown option to rndrect $opt"
            }
        }
    }
    set pts {}
    # top edge + top-right corner
    for {set i 0} {$i <= $steps} {incr i} {
        set a [expr {90.0 - ($i*90.0/$steps)}]
        set rad [expr {$a*acos(-1)/180.0}]
        lappend pts [expr {$x2-$r + $r*cos($rad)}] [expr {$y1+$r - $r*sin($rad)}]
    }
    # right edge + bottom-right corner
    for {set i 0} {$i <= $steps} {incr i} {
        set a [expr {0.0 - ($i*90.0/$steps)}]
        set rad [expr {$a*acos(-1)/180.0}]
        lappend pts [expr {$x2-$r + $r*cos($rad)}] [expr {$y2-$r - $r*sin($rad)}]
    }
    # bottom edge + bottom-left corner
    for {set i 0} {$i <= $steps} {incr i} {
        set a [expr {270.0 - ($i*90.0/$steps)}]
        set rad [expr {$a*acos(-1)/180.0}]
        lappend pts [expr {$x1+$r + $r*cos($rad)}] [expr {$y2-$r - $r*sin($rad)}]
    }
    # left edge + top-left corner
    for {set i 0} {$i <= $steps} {incr i} {
        set a [expr {180.0 - ($i*90.0/$steps)}]
        set rad [expr {$a*acos(-1)/180.0}]
        lappend pts [expr {$x1+$r + $r*cos($rad)}] [expr {$y1+$r - $r*sin($rad)}]
    }

    return $pts
}
