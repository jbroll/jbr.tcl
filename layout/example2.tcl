#!/usr/bin/env tclsh
#
package require Tk
package require jbr::layout
package require jbr::layoutoption
package require jbr::layoutdialog
package require jbr::layoutoptmenu

proc bgerror { args } {
    print {*}$args
}

# UI to App interface is composed of these global variables
#
#

# ::partial is the variable containing name of the partial result text widget
# ::final   is the variable containing name of the final result text widget
#
# proc quit is expected to clean up and exit the app.
#
# The app supplies a list of string names for the available input devices for
# the user to select from in the global ::input_devices


# Transcription state and user feedback.  The App should trace ::transcriptoin to
# monitor state and set ::audiolevel and ::confidence to provide user feedback.
#
set transcribing 0
set audiolevel   0
set confidence   0

# The global configuration array with the defaults
#
array set ::config {
    input_device          pulse
    energy_threshold       20
    confidence_threshold  175
    lookback_seconds        1.5
    silence_seconds         1.5
    vosk_beam              20
    vosk_lattice            8
    vosk_alternatives       1
}

set ::input_devices { a b pulse C D }

# UI initializaiton and callbacks -----------------------------------

proc audiolevel { value } { return [format "Audio: %7.2f" $value] }
proc confidence { value } { return [format "Conf: %7.0f" $value] }

set TranscribingStateLabel { Idle Transcribing }
set TranscribingStateColor { pink lightgreen }
set TranscribingButtonLabel { Start "Stop " }

set AudioRanges { { 0   10        50         75 } 
                  { pink lightblue lightgreen #40C040 } }

proc toggle { x } {
    set $x [expr { ![set $x] }]
}
grid [row .w -sticky news {
    # Global options
    #
    -sticky news
    -label.pady 6

    @ Transcribing -text :transcribing@TranscribingStateLabel  -bg :transcribing@TranscribingStateColor -width 15
    ! Start        -text :transcribing@TranscribingButtonLabel -command "toggle ::transcribing"         -width 15
    @ "" -width 5
    @ Audio: -text :audiolevel!audiolevel -bg :audiolevel&AudioRanges   -width 10
    @ Conf:  -text :confidence!confidence                               -width 10
    @ "" -width 5
    ! Config -command config 
    ! Quit -command quit                                &
    text ::final   -width 60 -height  2 - - - - - - -   &
    text ::partial -width 60 -height 10 - - - - - - -  
 }] -sticky news

proc config {} {
    layout-dialog-show .dlg "Talkie Configuration" {
        -label.pady 6
        -scale.length 200
        -scale.showvalue false
        -scale.orient horizontal
        -scale.width 20

        @ "Input Device" x                           ??    ? config(input_device) -listvariable input_devices         &
        @ "Audio Level"  @ :config(energy_threshold)     -width 10 <--> config(energy_threshold)     -from 0 -to 200 &
        @ "Confidence"   @ :config(confidence_threshold) -width 10 <--> config(confidence_threshold) -from 0 -to 200 &
        @ "Lookback"     @ :config(lookback_seconds)     -width 10 <--> config(lookback_seconds)     -from 0 -to   3 &
        @ "Silence"      @ :config(silence_seconds)      -width 10 <--> config(silence_seconds)      -from 0 -to   3 &
        @ "Vosk Beam"    @ :config(vosk_beam)            -width 10 <--> config(vosk_beam)            -from 0 -to  50 &
        @ "Lattice Beam" @ :config(vosk_lattice)         -width 10 <--> config(vosk_lattice)         -from 0 -to  20 &
        @ "Alternatives" @ :config(vosk_alternatives)    -width 10 <--> config(vosk_alternatives)    -from 1 -to   3 
    }
}

