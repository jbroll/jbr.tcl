#!/usr/bin/env wish9.0

package require Tk
package require Img

package require jbr::layout
source /home/john/src/jbr.tcl/layout/ngon.tcl
source /home/john/src/jbr.tcl/layout/rndrect.tcl
source /home/john/src/jbr.tcl/layout/canvas-oo.tcl
source /home/john/src/jbr.tcl/canv2svg.tcl

package require jbr::2d
package require jbr::print

set ::lastDir "~"
set ::currentFile ""

proc draw {} {

    namespace eval D {
        try {
            try { ::canv erase page } on error msg { print $msg }
            ::canv csys 0 0 page [.text get 1.0 end]
        } on error msg { print $msg }
    }
}

proc svg {} {
    global ::lastDir
    set filename [tk_getSaveFile \
        -initialdir $::lastDir \
        -defaultextension .svg \
        -filetypes {{"SVG Files" {.svg}} {"All Files" *}} \
        -title "Save SVG File As"]

    if {$filename eq ""} {
        return
    }

    set ::lastDir [file dirname $filename]
    set svgtext [canvas_to_svg .c viewbox]

    set f [open $filename w]
    puts $f $svgtext
    close $f
}

proc png {} {
    global ::lastDir

    set filename [tk_getSaveFile \
        -initialdir $::lastDir \
        -defaultextension .png \
        -filetypes {{"PNG Files" {.png}} {"All Files" *}} \
        -title "Save PNG File As"]

    if {$filename eq ""} {
        return
    }
    set ::lastDir [file dirname $filename]

    # Get the bounding box of the viewbox item
    set bbox [.c bbox viewbox]

    set cw [.c cget -width]
    set ch [.c cget -height]

    if {$bbox eq ""} {
        set w [.c cget -width]
        set h [.c cget -height]
        # Fallback: use the full canvas
        set x1 0
        set y1 0
        set x2 $w
        set y2 $h
    } else {
        # bbox returns list: x1 y1 x2 y2
        lassign $bbox x1 y1 x2 y2
        set w [expr {int($x2-$x1)}]
        set h [expr {int($y2-$y1)}]
    }

    # Create a temporary image and copy the canvas contents
    set img [image create photo -width $cw -height $ch]
    .c image $img
    set png [image create photo -width $w -height $h]
    $png copy $img -from $x1 $y1 $x2 $y2

    # Save PNG
    $png write $filename -format png
    rename $img {}
    rename $png {}
}

proc file-open {textWidget} {
    global ::lastDir ::currentFile
    set filename [tk_getOpenFile \
        -initialdir $::lastDir \
        -filetypes {{"Diagram Files" {.dtk}} {"All Files" *}} \
        -title "Open Diagram File"]
    if {$filename ne ""} {
        set f [open $filename r]
        set filedata [read $f]
        close $f

        $textWidget delete 1.0 end
        $textWidget insert end $filedata

        set ::lastDir [file dirname $filename]
        set ::currentFile $filename

        draw
    }
}

proc file-saas {textWidget} {
    global ::lastDir ::currentFile
    set filename [tk_getSaveFile \
        -initialdir $::lastDir \
        -defaultextension .dtk \
        -filetypes {{"Diagram Files" {.dtk}} {"All Files" *}} \
        -title "Save Diagram File As"]

    if {$filename eq ""} { return }

    set ::lastDir [file dirname $filename]
    set ::currentFile $filename

    file-save
}

proc file-save {textWidget} {
    if {$::currentFile eq ""} {
        file-saas $textWidget
    } else {
        set f [open $::currentFile w]
        puts $f [$textWidget get 1.0 end]
        close $f
    }
}

proc confirm-quit {} {
    if {[tk_messageBox -type yesno -icon question -title "Quit" -message "Are you sure you want to quit?"] eq "yes"} {
        exit
    }
}

grid [button .open -text "Open"    -command {file-open .text}]  \
     [button .save -text "Save"    -command {file-save .text}]  \
     [button .saas -text "Save As" -command {file-saas .text}]  \
     [button .quit -text "Quit"    -command {confirm-quit}]     \
     [button .xsvg -text "SVG"     -command {svg}]              \
     [button .xpng -text "PNG"     -command {png}]              \
     [button .draw -text "Draw"    -command {draw}] -           \
     -sticky news

grid [text .text -width 60 -height 15] - - -                     \
     [canvas .c -height 600 -width 600 -background white] - - - -sticky news

canvas-oo create canv .c

bind . <Control-q> {confirm-quit}                ;# Quit with confirmation
bind . <Control-k> {exit}                        ;# Quit immediately
bind . <Control-o> {file-open .text}             ;# Open
bind . <Control-s> {file-save .text}             ;# Save
bind . <Control-S> {file-saas .text}             ;# Save As (Shift-S)
bind . <Control-w> {draw}                        ;# Draw

if {[llength $argv] > 0} {
    set fileArg [lindex $argv 0]
    if {[file exists $fileArg]} {
        .text delete 1.0 end

        set ::currentFile $fileArg
        set ::lastDir [file dirname $fileArg]

        set f [open $fileArg r]
        .text insert end [read $f]
        close $f

        draw
    }
}

wm protocol . WM_DELETE_WINDOW {confirm-quit}
