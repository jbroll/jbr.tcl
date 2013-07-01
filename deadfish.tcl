
namespace eval deadfish {
    proc eval { code } {
	variable n 0

	::eval [join [split [regsub -all -- {[^idso]} $code {}] {}] \n]
    }

    proc ! {} { uplevel { variable n; set n [expr (($n==256||$n<0)) ? 0 : $n] } }

    proc i {} { !; incr n    }
    proc d {} { !; incr n -1 }
    proc s {} { !; set n [expr $n*$n] }
    proc o {} { !; puts $n }
}

deadfish::eval {
    iisiiiisiiiiiiiioiiiiiiiiiiiiiiiiiiiiiiiiiiiiioiiiiiiiooiiio
    dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddo
    dddddddddddddddddddddsddoddddddddoiiioddddddoddddddddo
}

deadfish::eval iissso
deadfish::eval iissiso

