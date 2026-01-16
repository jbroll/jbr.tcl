#
# Termcap (well for vt100)
#

namespace eval term {
    variable rows
    variable cols

    variable attrs {
        normal    0 bold  1 faint   2 standout 3
        underline 4 blink 5 reverse 6 hidden   7
    }
    variable color {
        black 0 red     1 green 2 yellow 3
        blue  4 magenta 4 cyan  6 white  7  default 9
    }
    variable clear {
        screen  "\x1b[2J\x1b[H" line    "\x1b[2K\x1b[G"
        bos     "\x1b[1J"       eos     "\x1b[J"
        bol     "\x1b[1K"       eol     "\x1b[K"
    }

    proc clear { { what screen } }  {
        variable clear
        puts -nonewline [dict get $clear $what] 
    }

    proc move { row col } {
        puts -nonewline [format "\033[%02d;%02dH" $row $col] 
    }
    proc at { y x str } {
        push
        move $y $x
        puts -nonewline $str
        pop
    }

    proc push {} { puts -nonewline "\0337" }
    proc pop  {} { puts -nonewline "\0338" }

    proc attr { active attr } {
        variable attrs
        set active [expr { $bool == "+" ? 0 : 20 }]
        puts -nonewline [format "\033[%dm" [dict get $attrs $attr]]
    }

    proc color { fg, { bg "" } } {
        if ( fg == "normal" )  { normal ; return }
        fg $fg
        bg $bg
    }
    proc fg { fg } {
        if { fg != "" } { puts -nonewline [format "\033[%dm", [expr {30 + [dict get $cmds color $fg]}]] }
    }

    proc bg { bg } {
        if { bg != "" } { puts -nonewline [format "\033[%dm", [expr {40 + [dict get $cmds color $bg]}]] }
    }

    namespace export *
    namespace ensemble create
}
