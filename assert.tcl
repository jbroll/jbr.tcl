
proc assert-eq { a b msg } {
    set va [uplevel $a]
    set vb [uplevel $b]
    if { $va ne $vb } {
        error "failed assert $va != $vb : $a :: $b ::: $msg"
    }
}

