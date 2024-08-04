package require jbr::seconds

proc truncate_timestamp {timestamp interval} {
    return [expr {$timestamp - ($timestamp % $interval)}]
}

proc cron { when action } {
    switch -regexp $when {
        {^Sun|Mon|Tue|Wed|Thu|Fri|Sat at [0-9][0-9]:[0-9][0-9]$} {
            cron:at $when {%A at %H:%M} $action [milliseconds 7d]
        }
        {^[0-9][0-9]:[0-9][0-9]$} {
            cron:at $when {%H:%M} $action [milliseconds 1d]
        }
        {^every hour at ([0-9][0-9]) minute$} {
            regexp {([0-9][0-9])} $when -> minute
            cron:every_interval 3600 [expr {$minute * 60}] $action
        }
        {^every minute at ([0-9][0-9]) second$} {
            regexp {([0-9][0-9])} $when -> second
            cron:every_interval 60 $second $action
        }
    }
}

proc cron:at { time fmt cmd period } {
    set next [expr {int([clock scan $time -format $fmt]-[clock seconds])*1000}]
    if { $next <= 0 } {
        set next [expr { int($period + $next) }]
    }
    return [after $next "try { $cmd }; after 1000; after idle [namespace code [info level 0]]"]
}

proc cron:every_interval { interval offset cmd } {
    global now
    set current_time [expr {[info exists now] ? $now : [clock seconds]}]
    set next [expr {[truncate_timestamp $current_time $interval] + $offset}]
    
    while {$next <= $current_time} {
        set next [expr {$next + $interval}]
    }
    
    set delay [expr {($next - $current_time) * 1000}]
    
    return [after $delay "try { $cmd }; after 1000; after idle [namespace code [list cron:every_interval $interval $offset $cmd]]"]
}