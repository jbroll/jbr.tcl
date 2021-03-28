
set ::ASSERT_FAIL error

proc assert-fail { reason } {
    return -code $::ASSERT_FAIL $reason
}

proc assert-eq { va vb msg } {
    if { $va != $vb } {
        assert-fail "failed assert $va != $vb : $msg"
    }
}

