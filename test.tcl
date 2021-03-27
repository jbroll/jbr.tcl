package require jbr::assert
package require jbr::func
package require jbr::list
package require jbr::print

interp alias {} eq {} assert-eq

namespace eval test {
    set SKIP 10

    proc skip { reason } {
        return -code $test::SKIP $reason
    }

    proc platform { name eq value } {
        if "\$::tcl_platform(\$name) $eq \$value" {
        } else { skip "platform constraint $name $eq $value but is $::tcl_platform($name)" }
    }

    proc check-options { options args } {
        if { [llength $args] %2 } {
            error "expecting an even number of option block pairs"
        }
        set dup {}
        foreach option [lselect $args {*}[iota 0 [llength $args]/2 2]] {
            if { ![regexp [join $options |]|{case-.*} $option] } {
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
        namespace eval ::test $code
    }

    proc test { name body } {
        set options [check-options { setup case cleanup } {*}$body]

        set it [interp create]
        $it eval {
            package require jbr::test
        }

        foreach {phase code} $options {
            try {
                $it eval namespace eval ::test [list $code]
            } on error e {
                print FAIL $name in $phase $e
                return
            } on $test::SKIP e {
                print SKIP $name in $phase $e
                return
            }

        }
        interp delete $it

        print PASS $name
    }
}
