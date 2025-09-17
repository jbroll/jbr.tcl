#!/usr/bin/env tclsh
#
package require Tk
package require jbr::layout
package require jbr::layoutoption
package require jbr::layoutdialog

proc bgerror { args } {
    print {*}$args
}

# UI to App interface is composed of these global variables
#
set transcribing 0
set audiolevel   0
set confidence   0

array set ::ui {
    energy_threshold       20
    confidence_threshold  175
    lookback_seconds        1.5
    silence_seconds         1.5
    vosk_beam              20
    vosk_lattice            8
    vosk_alternatives       1
}

# UI initializaiton and callbacks -----------------------------------

proc audiolevel { value } { return [format "Audio: %7.2f" $value] }
proc confidence { value } { return [format "Conf: %7.0f" $value] }

set TranscribingStateLabel { Idle Transcribing }
set TranscribingStateColor { pink lightgreen }
set TranscribingButtonLabel { Start Stop }

set AudioRanges { { 0   10        50         75 } 
                  { pink lightblue lightgreen #40C040 } }

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
        ! Quit -command quit                      &
        text ::partial -width 75 -height 10 - - - - - - -   &
        text ::final   -width 75 -height  2 - - - - - - -  
 }] -sticky news

proc config {} {
    layout-dialog-show .dlg "Talkie Configuration" {
        -label.pady 6
        -scale.length 200
        -scale.showvalue false
        -scale.orient horizontal
        -scale.width 20

        @ "Audio Level"  @ :ui(energy_threshold)     -width 10 <--> ui(energy_threshold)  -from 0 -to 200 &
        @ "Confidence"   @ :ui(confidence_threshold) -width 10 <--> ui(confidence_threshold) -from 0 -to 200 &
        @ "Lookback"     @ :ui(lookback_seconds)     -width 10 <--> ui(lookback_seconds)     -from 0 -to   3 &
        @ "Silence"      @ :ui(silence_seconds)      -width 10 <--> ui(silence_seconds)      -from 0 -to   3 &
        @ "Vosk Beam"    @ :ui(vosk_beam)            -width 10 <--> ui(vosk_beam)            -from 0 -to  50 &
        @ "Lattice Beam" @ :ui(vosk_lattice)         -width 10 <--> ui(vosk_lattice)         -from 0 -to  20 &
        @ "Alternatives" @ :ui(vosk_alternatives)    -width 10 <--> ui(vosk_alternatives)    -from 1 -to   3 
    }
}

