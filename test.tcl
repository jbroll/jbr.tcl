package require jbr::assert
package require jbr::func
package require jbr::list
package require jbr::print

interp alias {} eq {} assert-eq
interp alias {} true {} assert-true
interp alias {} false {} assert-false

namespace eval test {
    set setup {}
    set SKIP_CODE 10
    set FAIL_CODE 11
    set ::ASSERT_FAIL $FAIL_CODE

    proc check-options { options args } {
        if { [llength $args] %2 } {
            error "expecting an even number of option block pairs"
        }
        set dup {}
        foreach option [lselect $args {*}[iota 0 [llength $args]/2 2]] {
            if { ![regexp [join ^$options\$ |]|case-.* $option] } {
                error "unknown option : $option expecting one of $options"
            }
            if { [dict exists $dup $option] } {
                error "duplicate option block : $option"
            }
            dict set dup $option 1
        }

        # Set default empty blocks for well known options, with setup first and 
        # then move cleanup to the end.
        # 
        set options [dict merge [zip $options [lrepeat [llength $options] {}]] $args]
        dict merge [dict remove $options cleanup] [list cleanup [dict get $options cleanup]]
    }

    proc suite { name code } {
        variable PASS 0
        variable SKIP 0
        variable WARN 0
        variable FAIL 0

        print $name
        try {
            namespace eval ::test $code
            incr PASS
        } on $test::SKIP_CODE e {
            print " " SKIP suite $name: $e
            incr SKIP
        }

        print "  PASS" $PASS SKIP $SKIP WARN $WARN FAIL $FAIL
    }

    proc setup { script } {
        variable setup $script
    }

    proc skip { reason } {
        return -code $test::SKIP_CODE $reason
    }

    proc platform { name eq value } {
        if "\$::tcl_platform(\$name) $eq \$value" {
        } else { skip "platform constraint $name $eq $value but is $::tcl_platform($name)" }
    }


    proc test { name body } {
        variable SKIP 
        variable FAIL

        set options [check-options { skip setup cleanup } {*}$body]
        variable setup

        set it [interp create]
        $it eval {
            package require jbr::test
            namespace path ::test
        }
        $it eval $setup

        foreach {phase code} $options {
            if { $phase eq "skip" && $code ne "" } {
                print "  SKIP test $name: $code"
                incr SKIP
                return
            }
            try {
                $it eval $code
            } on $test::FAIL_CODE {e options} {
                print " " FAIL $name in $phase $e $options
                incr FAIL
                return
            } on $test::SKIP_CODE e {
                print " " SKIP case $name in $phase $e
                incr SKIP
            }
        }
        interp delete $it

        print " " PASS $name
    }
}
