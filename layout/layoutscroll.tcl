# layoutscroll.tcl -- scrollable container for layout DSL
#
# This module adds a scrollable container to the jbr.tcl layout system.
# It wraps the canvas-with-embedded-frame pattern into a simple container.
#
# Usage in layout DSL:
#   scroll .name { body }               ;# vertical scrollbar (default)
#   scroll .name -scroll h { body }     ;# horizontal scrollbar
#   scroll .name -scroll vh { body }    ;# both scrollbars
#
# The body is laid out inside the scrollable region using standard layout DSL.
# The inner frame is accessible as .name.canvas.inner

proc scroll { w args } {
    set scroll [yank -scroll args v]
    set body [lindex $args end]
    set args [lrange $args 0 end-1]

    frame $w {*}$args

    set canv $w.canvas
    set opts {}
    if {[string match *v* $scroll]} {
        lappend opts -yscrollcommand [list $w.vsb set]
    }
    if {[string match *h* $scroll]} {
        lappend opts -xscrollcommand [list $w.hsb set]
    }
    canvas $canv -highlightthickness 0 {*}$opts

    if {[string match *v* $scroll]} {
        ttk::scrollbar $w.vsb -orient vertical -command [list $canv yview]
    }
    if {[string match *h* $scroll]} {
        ttk::scrollbar $w.hsb -orient horizontal -command [list $canv xview]
    }

    set inner $canv.inner
    frame $inner
    $canv create window 0 0 -anchor nw -window $inner -tags inner

    layout -in $inner -type row $body

    bind $inner <Configure> "$canv configure -scrollregion \[$canv bbox all\]"

    bind $canv <MouseWheel>       {%W yview scroll [expr {-%D/120}] units}
    bind $canv <Button-4>         {%W yview scroll -3 units}
    bind $canv <Button-5>         {%W yview scroll  3 units}
    bind $canv <Shift-MouseWheel> {%W xview scroll [expr {-%D/120}] units}
    bind $canv <Shift-Button-4>   {%W xview scroll -3 units}
    bind $canv <Shift-Button-5>   {%W xview scroll  3 units}

    grid $canv -row 0 -column 0 -sticky nsew
    if {[string match *v* $scroll]} {
        grid $w.vsb -row 0 -column 1 -sticky ns
    }
    if {[string match *h* $scroll]} {
        grid $w.hsb -row 1 -column 0 -sticky ew
    }
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure $w 0 -weight 1

    return $w
}

package provide jbr::layout::scroll 1.0
