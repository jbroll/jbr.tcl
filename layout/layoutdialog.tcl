
proc centerWindow {win {parent .}} {
    update idletasks            ;# make sure geometry info is current

    # size of parent
    set pw [winfo width  $parent]
    set ph [winfo height $parent]
    set px [winfo rootx  $parent]
    set py [winfo rooty  $parent]

    # size of window
    set ww [winfo reqwidth  $win]
    set wh [winfo reqheight $win]

    # compute centered position
    set x [expr {$px + ($pw - $ww) / 2}]
    set y [expr {$py + ($ph - $wh) / 2}]

    wm geometry $win +$x+$y
}

proc layout-dialog { w title body } {
    toplevel .dlg
    wm title .dlg "Talkie Configuration"
    wm withdraw .dlg
    frame .dlg.x
    grid [row -in .dlg.x -sticky news $body]
    update idletasks
    centerWindow .dlg .
    wm deiconify .dlg
    focus -force .dlg
    raise .dlg
}

proc layout-dialog-show { w title body } {
    if { [winfo exists $w] } {
        raise $w
        return
    }
    layout-dialog $w $title $body
    return $w
}
