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

# Mock 'after' command
proc after {args} {
    lappend ::after_calls $args
    return "mocked_timer_id"
}

# Reset the mock
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

# Test cron:every_interval function
test cron_every_interval-1 {Test hourly execution} -setup {
    reset_mock
    set ::now 1628097123  ; # 2021-08-04 15:45:23 UTC
    set test_cmd {puts "Test command executed"}
} -body {
    cron:every_interval 3600 0 $test_cmd
    list [llength $::after_calls] [lindex $::after_calls 0 0]
} -result [list 1 2877000]

test cron_every_interval-2 {Test minute execution} -setup {
    reset_mock
    set ::now 1628097123  ; # 2021-08-04 15:45:23 UTC
    set test_cmd {puts "Test command executed"}
} -body {
    cron:every_interval 60 0 $test_cmd
    list [llength $::after_calls] [lindex $::after_calls 0 0]
} -result [list 1 57000]

# Test cron function
test cron-1 {Test "every hour at XX minute"} -setup {
    reset_mock
    set ::now 1628097123  ; # 2021-08-04 15:45:23 UTC
    set test_cmd {puts "Test command executed"}
} -body {
    cron "every hour at 45 minute" $test_cmd
    list [llength $::after_calls] [lindex $::after_calls 0 0]
} -result [list 1 1977000]

test cron-2 {Test "every minute at XX second"} -setup {
    reset_mock
    set ::now 1628097123  ; # 2021-08-04 15:45:23 UTC
    set test_cmd {puts "Test command executed"}
} -body {
    cron "every minute at 00 second" $test_cmd
    list [llength $::after_calls] [lindex $::after_calls 0 0]
} -result [list 1 57000]

# Run the tests
if {[info exists ::argv0] && [file tail [info script]] eq [file tail $::argv0]} {
    runAllTests
}
