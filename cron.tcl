package require jbr::seconds
package require jbr::print

proc truncate_timestamp {timestamp interval} {
    return [expr {$timestamp - ($timestamp % $interval)}]
}

proc cron { when action } {
    switch -regexp -matchvar matches $when {
        {^ *Sun|Mon|Tue|Wed|Thu|Fri|Sat +at +[0-9][0-9]:[0-9][0-9] *$} {
            cron:at $when {%A at %H:%M} $action [milliseconds 7d]
        }
        {^ *[0-9][0-9]:[0-9][0-9 *]$} {
            cron:at $when {%H:%M} $action [milliseconds 1d]
        }
        {^ *every ([0-9]+[smhdwty]) +at +([0-9]+[smhdwty]) *$} {
            lassign $matches -> interval offset
            cron:every [milliseconds $interval] [milliseconds $offset] $action
        }
        {^ *every +hour +at +([0-9][0-9]?) +minutes.*$} {
            lassign $matches -> minute
            cron:every [milliseconds 1h] [milliseconds ${minute}m] $action
        }
        {^ *every +minute +at +([0-9][0-9]?) +seconds.*$} {
            lassign $matches -> second
            cron:every [milliseconds 1m] [milliseconds ${second}s] $action
        }
        {.*} {
            error "No match for cron request $when"
        }
    }
}

proc cron:now {} {
    return [clock milliseconds]
}

proc cron:at { time fmt cmd period } {
    set next [expr { int([clock scan $time -format $fmt] * 1000 - [cron:now])}]
    while { $next <= 0 } {
        set next [expr { int($period + $next) }]
    }
    return [after $next "try { $cmd }; after 1000; after idle [namespace code [info level 0]]"]
}

proc cron:every { interval offset cmd } {
    set now [cron:now]
    set next [expr { [truncate_timestamp $now $interval] + $offset - [cron:now] }]
    while { $next <= 0 } {
        set next [expr {$next + $interval}]
    }
    return [after $next "try { $cmd }; after 1000; after idle [namespace code [info level 0]]"]
}
