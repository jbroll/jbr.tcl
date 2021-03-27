
proc assert-fail { reason } {
    error $reason
}

proc assert-eq { va vb msg } {
    if { $va != $vb } {
        assert-fail "failed assert $va != $vb : $msg"
    }
}

