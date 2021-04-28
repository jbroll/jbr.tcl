
proc 0x { value { width 8 } } { format 0x%0*X $width [expr { entier($value) }] }

proc  print { args } { puts stdout [join $args " "] }
proc eprint { args } { puts stderr [join $args " "] }

