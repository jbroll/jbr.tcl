
set ::ASSERT_FAIL error

proc assert-fail { reason } {
    return -code $::ASSERT_FAIL $reason
}

proc assert-eq { va vb { msg "" } } {
    if { [uplevel 1 $va] != $vb } {
        assert-fail "failed assert $va != $vb : $msg"
    }
}

proc assert-true { va { msg "" } } {
    if { ![uplevel 1 $va] } {
        assert-fail "failed assert $va not true : $msg"
    }
}

proc assert-false { va { msg "" } } {
    if { [uplevel 1 $va] } {
        assert-fail "failed assert $va not false : $msg"
    }
}
