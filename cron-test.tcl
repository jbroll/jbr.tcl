package require tcltest
namespace import ::tcltest::*

# Configure tcltest to only run tests in this file
configure -testdir [file dirname [info script]]
configure -file [file tail [info script]]
configure -singleproc true

# Prevent recursive sourcing
if {[info exists ::cron_tests_loaded]} return
set ::cron_tests_loaded 1

# Include the main cron script
source "cron.tcl"

proc after {args} {
    lappend ::after_calls $args
    return "mocked_timer_id"
}

proc cron:now {} {
    return $::mock_now
}
#
proc reset_mock {} {
    set ::after_calls {}
}

# Test truncate_timestamp function
test truncate_timestamp-1 {Test truncate_timestamp for hour} -setup {
    set timestamp 1628097123  ; # Wed Aug  4 01:12:03 PM EDT 2021
} -body {
    truncate_timestamp $timestamp 3600
} -result 1628096400

test truncate_timestamp-2 {Test truncate_timestamp for 15 minutes} -setup {
    set timestamp 1628097123  ; # Wed Aug  4 01:12:03 PM EDT 2021
} -body {
    truncate_timestamp $timestamp 900
} -result 1628096400

test truncate_timestamp-3 {Test truncate_timestamp for day} -setup {
    set timestamp 1628097123  ; # 2021-08-04 15:45:23 UTC
} -body {
    truncate_timestamp $timestamp 86400
} -result 1628035200

# Test cron:every function
test cron_every-1 {Test hourly execution} -setup {
    reset_mock
    set ::mock_now 1628097123000  ; # Wed Aug  4 01:12:03 PM EDT 2021
    set test_cmd {puts "Test command executed"}
} -body {
    cron:every 3600000 0 $test_cmd
    list [llength $::after_calls] [lindex $::after_calls 0 0]
} -result [list 1 2877000]

test cron_every-2 {Test minute execution} -setup {
    reset_mock
    set ::mock_now 1628097123000  ; # Wed Aug  4 01:12:03 PM EDT 2021
    set test_cmd {puts "Test command executed"}
} -body {
    cron:every 60000 0 $test_cmd
    list [llength $::after_calls] [lindex $::after_calls 0 0]
} -result [list 1 57000]

# Test cron function
test cron-1 {Test "every hour at XX minutes"} -setup {
    reset_mock
    set ::mock_now 1628097123000  ; # wed aug  4 01:12:03 pm edt 2021
    set test_cmd {puts "Test command executed"}
} -body {
    cron "every hour at 45 minutes" $test_cmd
    list [llength $::after_calls] [lindex $::after_calls 0 0]
} -result [list 1 1977000]

test cron-2 {Test "every minute at XX seconds"} -setup {
    reset_mock
    set ::mock_now 1628097123000  ; # wed aug  4 01:12:03 pm edt 2021
    set test_cmd {puts "Test command executed"}
} -body {
    cron "every minute at 00 seconds" $test_cmd
    list [llength $::after_calls] [lindex $::after_calls 0 0]
} -result [list 1 57000]

test cron-3 {Test "every Xh at Xm minutes"} -setup {
    reset_mock
    set ::mock_now 1628097123000  ; # wed aug  4 01:12:03 pm edt 2021
    set test_cmd {puts "Test command executed"}
} -body {
    cron "every 1h at 45m" $test_cmd
    list [llength $::after_calls] [lindex $::after_calls 0 0]
} -result [list 1 1977000]

test cron-4 {Test "every Xm at Xs minutes"} -setup {
    reset_mock
    set ::mock_now 1628097123000  ; # wed aug  4 01:12:03 pm edt 2021
    set test_cmd {puts "Test command executed"}
} -body {
    cron "every 1m at 0s" $test_cmd
    list [llength $::after_calls] [lindex $::after_calls 0 0]
} -result [list 1 57000]

test cron-5 {Test "every Xm at Xs minutes"} -setup {
    reset_mock
    set ::mock_now 1628097123000  ; # wed aug  4 01:12:03 pm edt 2021
    set test_cmd {puts "Test command executed"}
} -body {
    cron "every 3m at 3s" $test_cmd
    list [llength $::after_calls] [lindex $::after_calls 0 0]
} -result [list 1 180000]

# Run the tests
if {[info exists ::argv0] && [file tail [info script]] eq [file tail $::argv0]} {
    runAllTests
}
