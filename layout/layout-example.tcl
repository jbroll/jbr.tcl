
package require jbr::layout

grid [row .w -sticky news {
    # Global options
    # Every one is sticky, column 1 is strechy, labels are a little bigger than default
    #
    -sticky news
    -colweight 1
    -label.pady 6

        # A row of a label, "Start" button, "Stop" button and status label.  The
        # widget name of the status label of stored in ::status so that its text
        # can be updated by the script.
        #
        @ Guide ! "Start" -command guide-start ! "Stop"       -command guide-stop @ ::status Status
    &   @ View  ! "Boxes" -command view-boxes  ! "Full Image" -command view-full ! "All Images" -command view-all


        # These radiobuttons all set the fiber and call "set-fiber"
        #
    &   . -radiobutton.variable fiber
        . -radiobutton.command "set-fiber"

        @ Fiber  radiobutton -text Large  -value large
                 radiobutton -text Medium -value medium
                 radiobutton -text Small  -value small
    &   ! "Guide at Offset Position" -command guide-at-offset   x
        row -background red -sticky news {
                -label.pady 6
                -label.padx 4

                -sticky news
                    @ "X Offset" = XOff -width 5
                    @ "Y Offset" = YOff -width 5 } -
    &   ! ::transfer "Transfer Box"  -command guide-transfer x ! "Guide on target" ! "Guide on star"
    &   ! "Guide at Fiber Position"  -command guide-at-fiber
    &   ! "Combine Guide Images" -command guide-combine x = count -width 6 -justify r ! "Clear Images" -command clear-im
    &   x @ "Output Image" = imdir -width 10
    &   @ ""
    &   @ "Exposure Times" -anchor n
       row {

            label -width 7

            . -entry.width 5

              @ "Target"     = box1exp1 ! Set -command "setexp box1 1" = box1exp2 ! Set -command "setexp box1 2"
          & x @ "Guide Star" = box2exp1 ! Set -command "setexp box2 1" = box2exp2 ! Set -command "setexp box2 2"
          & x @ "Full Image" = fullexp1 ! Set -command "setexp full 1" = fullexp2 ! Set -command "setexp full 2"
        } - -

 }] -sticky news
