#!/bin/sh
# \
exec tclsh "$0" "$@"

lappend auto_path $env(MMTITCL)

proc keith_open { } { 
    global t1 
    global t2
	set t1 0
	set t2 1000
}

proc keith_read { no } {
    global t1 
    global t2
	if { $no == 1 } {
	    set t1 [expr {$t1 + 2}]
	    set data $t1
	}
	if { $no == 2 } {
	    set t2 [expr {$t2 - 1}]
	    set data $t2
	}
	return $data
}

proc getohms {} {
    global go
    global loginterval updaterate
    global counter
    global logchan
    global t1 t2

    set rdata1 [keith_read 1]
    set rdata2 [keith_read 2]
    if {($counter % $loginterval) == 0 } {
        set sec [clock seconds]
        set dt [clock format $sec]
        set logmsg [format "%s %d %s deg Ch#1 %s deg Ch#2" $dt $sec $rdata1 $rdata2]
        puts $logchan $logmsg
        flush $logchan
    }
    incr counter
    set t1 [format "%.2f" $rdata1]
    set t2 [format "%.2f" $rdata2]
    msg_post EXAMPLE temp1
    msg_post EXAMPLE temp2
    after $updaterate getohms
}

set loginterval 12
set updaterate 5000

proc EXAMPLE.tpset { server sock msgid cmd temp1 temp2 } {
	global t1 t2

	set t1 $temp1
	set t2 $temp2

	msg_ack $sock $msgid
}

msg_server   EXAMPLE 
msg_allow    EXAMPLE "*"
#msg_allow    EXAMPLE "no-one"
msg_publish  EXAMPLE temp1 t1 {} "-sub 1 -format %0.3f -units degrees F -- Temperature 1"
msg_publish  EXAMPLE temp2 t2 {} "-sub 1 -format %0.3f -units degrees F -- Temperature 2"
msg_register EXAMPLE tpset "-name temp1  -format %0.3f -units degrees F -- Temperature 1 \
			  -name temp2  -format %0.3f -units degrees F -- Temperature 2 \
			-- Set Temperature 1&2"

msg_up       EXAMPLE

set counter 0
keith_open
set logchan [open "keith.log" "a"]

getohms

set forever 1
vwait forever

