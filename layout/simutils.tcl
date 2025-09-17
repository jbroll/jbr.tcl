
proc toggle { x } {
    set $x [expr { ![set $x] }]
}
proc random { x max } {
    set $x [expr {rand() * $max}]
}

proc repeat { to args } {
    uplevel #0 {*}$args
    after $to repeat $to {*}$args
}

# repeat 2000 toggle ::transcribing
# repeat 2000 random ::audiolevel 100
# repeat 5000 random ::confidence 500

# repeat 2000 { print [array get ::ui] }
#

