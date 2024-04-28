# https://wiki.tcl-lang.org/page/Cryptographically+secure+random+numbers+using+%2Fdev%2Furandom

##################################################
# Random number generator, crypto quality
#################################################    
# Returns a random floating point number between $min and $max, inclusive
# With the default arguments, this is almost the same as expr rand()
# Doesn't work on Windows, only on Unix-based OS such as MacOSX and Linux
proc urandom {{min 0} {max 1}} {
   global tcl_platform
   if {$tcl_platform(platform) == "unix"} {
        set f [open /dev/urandom rb] ; set eightRandomBytes [read $f 8] ; close $f
       binary scan $eightRandomBytes h16 eightRandomBytesHex
       # n is an integer from 0 to 18446744073709551615 inclusive... lossless conversion
       set n [scan $eightRandomBytesHex %llx]
       # map n to min-max inclusive... maybe we lose a little randomness here (precision)
       if { $min eq "int" } {
           set randomNumber $n 
       } else {
           set randomNumber [expr (($n/18446744073709551615.0) * ($max - $min)) + $min]
       }

       return $randomNumber
   } else {
       error "getRandomNumber: Only works with Unix-based platforms"
   } 
}
