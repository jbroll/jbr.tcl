
set ::ASSERT_FAIL error

proc assert-fail { reason } {
    return -code $::ASSERT_FAIL $reason
}

proc warn { args } {
    try {
        uplevel $args
    } on $::ASSERT_FAIL e {
        print "  WARN" $e
    }
}

proc assert-eq { script vb { msg "" } } {
    set va [uplevel 1 $script]
    if { $va != $vb } {
        assert-fail "failed assert $va != $vb : $script: $msg"
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
