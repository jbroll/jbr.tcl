# msg.tcl Message Interface
#
# Copyright Smithsonain Institution 2006

package provide msg 2.0

set ::msg_logger	{}

set ::MsgSetting {}

proc msg_clock {} { expr { [clock clicks -milliseconds]/1000.0 } }

proc msg_debug { args } {
    catch {
        if { $::env(MSGDEBUG) != 0 } {
            puts stderr "[clock format [clock seconds]] $args"
        }
    }
}

proc msg_srvcoro { server name args body } {
    if { [llength $name] == 2 } {
	set proc [lindex $name 1]
	set name [lindex $name 0]
    } else {
	set proc $name
    }

    msg_register $server $name
    
    proc           $proc   $args  $body
    proc ::$server.$name { server sock msgid args } [subst {
	if { \[info commands ::$name-coro] ne {} } { 
	    error "command busy: ::$name-coro"
	}
	coroutine $name-coro msg_tryproc $proc \$sock \$msgid {*}\$args
    }]
}

proc msg_tryproc { proc sock msgid name args } {
    if { [catch {
        msg_ack $sock $msgid [$proc {*}$args]
    } reply] } {
        msg_nak $sock $msgid $reply
    }
}


proc msg_abort { server { msgid {} } } {
    upvar #0 $server S

    set $S(id,$$S(msgid)) -4
}

proc msg_wait { server msgid { cmd {} } } {
	msg_debug Wait: $server $msgid
	upvar #0 $server S

    if { [lindex $S(id,$msgid) 0] == 0 } {
        vwait ${server}(id,$msgid)
    }

    msg_debug Wait: $server $msgid continue
    catch { after cancel $S(to,$msgid) 
	        msg_debug "Timeout Canceled: $S(to,$msgid)"
    }

    set value $S(id,$msgid)
    set status [lindex [split $value " "] 0]

    if { $S(up) && $status != -3 } {
        msg_debug clear reopen timer
        catch { after cancel $S(reopen_timer) }
    }

    #set value [regexp -inline -all -- {\S+} $S(id,$msgid)]

    catch { unset S(id,$msgid) }
    catch { unset S(to,$msgid) }
    catch { unset S(cb,$msgid) }
    catch { unset S(sy,$msgid) }

    if { $status == -1 } {
        error $value
    }
    if { $status == -2 } {
        error "timeout $msgid $cmd"
    }
    if { $status == -3 } {
        error "server dead $msgid $cmd"
    }
    if { $status == -4 } {
        error "msg wait aborted $msgid $cmd"
    }
    if { $status == -5 } {
        error "msg wait callback error $msgid $cmd"
    }
    if { $status ==  1 } {
        return  [join [lrange [split $value " "] 1 end]]
    } 
}

proc msg_waitgroup { server group } {
    upvar #0 $server S

    set result {}
    set errors {}

    foreach msgid $S($group) {
	if { [catch { lappend result [msg_wait $server $msgid] } error] } {
	    lappend errors $error
	}
    }
    unset S($group)


    if { $errors != {} } {
	error $errors
    } else {
        return $result
    }
}

proc msg_reopen { server } {
	msg_debug msg_reopen: $server
	upvar #0 $server S

    set S(up) 0
    catch { after cancel $S(reopen_timer) }

    try {
        set sock [msg_setsock $server]
        set S($sock) [lindex [fconfigure $sock -peername] 1]
        set S($sock,tag) -
        return $sock
    } on error e {
        msg_debug msg_reopen $e
        catch { after cancel $S(reopen_timer) }
        set S(reopen_timer) [after $S(reopen) "msg_reopen $server"]
        return ""
    }
}

proc msg_cmd { server cmd { timeout {} } { sync sync } { code {} } } {
	upvar #0 $server S

    if { [string compare $sync nowait] } {
        set msgid $S(N)
        incr S(N) 2
    } else {
        set msgid 0
    }

    set sock $S(sock)
    set line [join [concat $msgid $cmd]]

    msg_debug msg_cmd $server $S(up): $line

    try {
        msg_debug msg_cmd try $sock $line
        puts $sock $line
        flush $sock
    } on error e {
        if { !$S(up) } {
            set sock [msg_reopen $server]
            if { $sock ne "" } {
                msg_debug msg_cmd try again $sock $line
                puts $sock $line
                flush $sock
            } else {
                return -3
            }
        }
    }

    if { [string compare $timeout {}] == 0 } {
        set timeout $S(timeout)
    }

    if { [string compare $sync nowait] } {
        set S(id,$msgid) 0
        set S(to,$msgid) [after $timeout "msg_timeout $server $msgid"]
    }

    set S(cb,$msgid) $code
    set S(sy,$msgid) $sync

    if { [string equal $sync sync] } {
        return [msg_wait $server $msgid $cmd]
    } elseif { [string equal $sync async] } {
        return $msgid
    } else {
        lappend S($sync) $msgid
        return $msgid
    }
}

proc msg_close { server } {
    upvar #0 $server S
	close $S(sock)
    if { [ string compare $S(logfile) NULL ] != 0 } {
	close $S(logfile)
    }
}

proc msg_sock { server } {
    upvar #0 $server S
	return $S(sock)
}

proc msg_getline { server sock } {
	upvar #0 $server S

    if { [eof $sock] } {
	close $sock
	return {}
    }
    if { [fblocked $sock] } {
	close $sock
	return {}
    }

    set len 0
    set err [catch { set len [gets $sock line] }]
    if { $len < 0 || $err == 1 } {
	if { $S(type) == 1 } {
	    msg_debug Kil Server $server EOL From server
        msg_kilclient  $server $sock 
	}
	if { $S(type) == 2 } { 
	    msg_debug Kil Client $S(sock) cannot read line from client
        msg_kilclient  $server $sock
    }

	close $sock
	set S(sock) ""

	if { $S(type) == 1 } {
	    set S(connection) Down

	    if { [catch { uplevel #0 $S(done) }] == 1 } {
		    global errorInfo

            tk_messageBox -icon error -type ok  \
                  -message "Error executing client done code: $errorInfo"
	    }

	    catch { after cancel $S(reopen_timer) }
        msg_debug set reopen timer
	    set S(reopen_timer) [after $S(reopen) "msg_reopen $server"]
	}
	return {}
    }

    return $line
}

proc msg_blkget { server name code } {
	upvar #0 $server S
	set S($name,blk) $code
}

proc msg_handle { server sock } {
	upvar #0 $server S

    set line [msg_getline $server $sock]

    if { [string compare $line {}] == 0 } {
    	return
    }

    if { [string match {[+0123456789]*} $line] == 0 } {
	set line "0 $line"
    }
    msg_debug "Handle $server: $line"

    if { [catch {
        set msgid  [lindex [split $line] 0]
        set cmd    [lindex [split $line] 1]
        set arg    [lindex [split $line] 2]
    }] } {
	error "Bad line from client: $line"
    }

    msg_logmsg $server $sock "cmd" $msgid $cmd $arg

    if { [catch { interp eval $server $cmd $server $sock [string map { [ \\[ $ \\$ } $line] } error] } {
	msg_nak $sock $msgid $error
	msg_logmsg $server $sock "err" "$cmd $arg"
    }
}

proc msg_tag { server value { timeout {} } { sync sync } } {
    if { ![string compare $sync {}] } {
	set sync sync
    }
    msg_cmd $server "tag $value" $timeout $sync
}

proc msg_set { server name value { timeout {} } { sync sync } } {
    if { ![string compare $sync {}] } {
	set sync sync
    }
    msg_cmd $server "set $name $value" $timeout $sync
}

proc msg_get { server name { timeout {} } { sync sync } { code {} } } {
    if { ![string compare $sync {}] } {
	set sync sync
    }
    msg_cmd $server "get $name" $timeout $sync $code
}

proc msg_list { server { timeout {} } } {
        upvar #0 $server S
 
    set sock $S(sock)

    msg_cmd $server "lst" $timeout

    set p {}
    while { 1 } {
        if { ![string compare				\
		[set line [msg_getline $server $sock]]  \
		"----LIST----"] } {
		break
	}
	lappend p "[lindex $line 0] [lindex $line 1] [list [lrange $line 2 end]]"
    }

    return $p
}

proc msg_alarm { server secs } {
	upvar #0 $server S
	global ALARM

  catch { 
    if { $secs } {
	#set S(sigalarm) [signal get ALRM]
	#set ALARM $server

	signal error ALRM ;
	alarm $secs
    } else {
	alarm 0
	#signal set $S(sigalarm)
    }
  } reply; #puts $reply
}

proc msg_aset { args } {
#	puts "msg_aset <ENTER> (args=$args)"
}

proc msg_setsock { server } {
	upvar #0 $server S
	msg_debug msg_setsock: $server $S(host) $S(port) $S(reopen)

    set host $S(host)
    set port $S(port)

    catch { close $S(sock) }
    catch { msg_kilclient $server $S(sock) }

    try { set sock [socket $host $port] } on error e {
	    global errorInfo
        msg_debug msg_setsock: $server $S(host) $S(port) cannot open socket

        error "host down : $server $host $port"
    }
    set S(sock) $sock
    msg_debug msg_setsock: $server $S(host) $S(port) socket : $S(sock)

    if { $S(__apikey) ne "" } {
        msg_debug msg_setsock: $server $S(host) $S(port) send apikey $S(__apikey)
        msg_cmd $server "api $S(__apikey)" 0 nowait
    }

    fileevent $sock readable "msg_handle $server $sock"
    fconfigure $sock -buffering line

    set $S(up) 1

    try { uplevel #0 $S(init) } on error e {
        set S(up) 0
		close $sock

        msg_debug client init $e

		puts "Error in client init code $::errorInfo"
		error "Error in client init code $::errorInfo"
    }

    try { 
        # Re-sync the variables in the message map
        #
        set wait {}
        set S(up) 1
        foreach m $S(+vars) { 
            set var  [lindex $m 0]
            set name [lindex $m 1]
            set init [lindex $m 2]

            global   $var
            upvar #0 $var v

            if { [string compare $init Server] == 0 \
             || ([string compare $init Up]     == 0 && $S(up) == 1) } {
                lappend wait [msg_get $server $name 30000 resync "msg_aset $var"]
            }
            if { [string compare $init Client] == 0 \
             || ([string compare $init Up]     == 0 && $S(up) == 0) } {
                lappend wait [msg_set $server $name $v 30000 resync]
            }
        }
        if { [string compare $wait {}] } { msg_waitgroup $server resync }
    } on error e {
        set $S(up) 0
        close $sock
        puts $e
        puts "Error syncing mapped vars with $server"
        puts $::errorInfo
        error "Error syncing mapped vars with $server"
    }

    try {
        # Re-establish the subscriptions
        #
        if { [string compare $S(+subs) {}] != 0 } {
            set wait {}

            foreach sub $S(+subs) {
                msg_debug msg_cmd $server "sub [lindex $sub 0] [lindex $sub 3]" 30000 subscribe msg_cset
                lappend wait [msg_cmd $server "sub [lindex $sub 0] [lindex $sub 3]" 30000 subscribe msg_cset]
            }
            if { [string compare $wait {}] } {
                try { msg_waitgroup $server subscribe } on error e {
                    msg_debug "Error reconnecting subscriptions : $e"
                } 
            }
        }
    } on error e {
        set S(up) 0
        close $sock

        puts "Error re-establishing subscriptions with $server"
        error "Error re-establishing subscriptions with $server"
    }

    #catch { msg_tag        $server [file tail $::argv0] 3000 nowait } reply ;# puts $reply

    # try retry here maybe?

    set S(connection) Up

    msg_debug Sock $server: DONE
    return $sock
}

proc msg_setreopen { server millis } {
    upvar $server S
    set S(reopen) $millis
}

proc ackdone { id server index op } {
    upvar $server S

    set response [lindex $S($index) 0]

    if { $S(up) } {
        if  { $response == -2 } {
            if { $S(connection) ne "Hung" } {
                set S(connection) Hung
            }
        } else {
            if { $S(connection) ne "Up" } {
                set S(connection) Up
            }
        }
    }
    print STATUS $server $S(connection)
    return

    if { [catch {
        trace vdelete  S($index) wu "ackdone $id"
        unset S($index)
        after cancel $S(to,${id})
        catch { unset S(to,${id}) }
    }] } {
        puts "ackdone : $reply"
    }
}

proc msg_keepalive { server { timeout 5000 } { updatetime 60000 } { prefix {} } } {
    upvar #0 $server S
    if { $S(up) } {
        catch {
            set id [msg_cmd $server ack $timeout async $prefix]

            if { [info exists S(id,$id)] } {
                trace variable S(id,$id) wu "ackdone $id"
            }
        }
    }

    after $updatetime "msg_keepalive $server $timeout $updatetime $prefix"
}

proc msg_uplevel { code args } {
	uplevel #0 $code $args
}

proc msg_subscribe { server name { var {} } { code {} } { update {} } { timeout {} } { sync sync } } {
	upvar #0 $server S
	if { $var == {} } { set var $name }

    set subscription [list $name $var $code $update]
	msg_debug CSub: $subscription
    if { $subscription in $S(+subs) } {
        msg_debug CSub: $server $name : duplicate
        return
    }

	if { ![info exists ::$var] } {
	    set ::$var {}
	}

	if { ![string compare $update {}] } {
		set update 1
	}

	set S($name) $var
	lappend S(+subs) $subscription
    set S(+subs) [lsort -unique $S(+subs)]

	if { [string compare $code {}] != 0 } {
	    trace variable ::$var w [list msg_uplevel $code]
	}

    if { $S(up) } { 
        try {
            msg_cmd $server "sub $name $update" $timeout $sync msg_cset
        } on error e {
            error "Error requesting subscription for $server:$name : $e"
        }
	}
}

proc msg_variables { server } {
	upvar #0 $server S
    return [lmap var [array names S P,*] { string range $var 2 end }]
}
proc msg_slst { server sock msgid lst } {
	msg_debug SLst: $server $sock $msgid
	upvar #0 $server S

	msg_ack $sock $msgid

	puts $sock "server	$server	$S(host):$S(port)"

	foreach { var comment } [array get S P,*] {
	    msg_debug  "published	[string range $var 2 end]	$comment"
	    puts $sock "published	[string range $var 2 end]	$comment"
	}
	foreach { cmd comment } [array get S R,*] {
	    msg_debug  "registered	[string range $cmd 2 end]	$comment"
	    puts $sock "registered	[string range $cmd 2 end]	$comment"
	}
	msg_puts $sock ----LIST----
	msg_logmsg $server $sock lst
}

proc msg_slog { server log } {
    msg_log $server $log
}

proc msg_blk { server name leng { timeout {} } { sync sync } { code {} } } {
    if { ![string compare $sync {}] } {
	set sync sync
    }
    msg_cmd $server "get $name $leng" $timeout $sync $code
}

proc msg_sget { server sock msgid get name args } {
	msg_debug SGet: $server $sock $msgid $name
	upvar #0 $server S

	if { [catch { set variable $S($name) }] } {
	    msg_nak $sock $msgid "No variable $name"
	    return
	}
	upvar #0 $variable var

	msg_debug SGet: $server $sock $msgid $name $S($name)

	if { [catch { msg_ack $sock $msgid $var }] } {
	    puts $::errorInfo
	    msg_nak $sock $msgid "cannot access $name"
	}
	if { [info exists S($name,blk)] } {
	    msg_debug SGet Call Block: $server $sock $msgid $name : $ S($name,blk)
	    catch { eval $S($name,blk) $server $sock $msgid } reply; #puts $reply
	}
}

proc msg_ssource { server sock msgid set args } {
	global env

	if [string compare -length 4 $sock file] \
		return

    	if [catch {
		set fname [subst [lindex $args 0]]
		set fd    [open $fname]
    		eval      [read $fd]
		close     $fd
	} reply] {
		puts $reply
	}
}

proc msg_stag { server sock msgid set args } {
    upvar #0 $server S

    set S($sock,tag) $args
    msg_ack $sock $msgid
}

proc msg_setting { sock } {
    set ::MsgSetting $sock
}

proc msg_sset { server sock msgid set args } {
	set name  [lindex $args 0]
	set value [lrange $args 1 end]

	msg_debug SSet: $server $sock $msgid $name $value
	upvar #0 $server S

	if { [catch {
 	    set variable $S($name)
	    upvar #0 $variable var

	    set ::MsgSetting $sock
	    set var $value
	    set ::MsgSetting {}
	    msg_ack $sock $msgid
	}] } {
	    puts $::errorInfo
	    msg_nak $sock $msgid "cannot access $name"
	}
}

proc msg_sack { server sock msgid ack args } {
	msg_ack $sock $msgid $args
}

proc msg_cset { server sock msgid set args } {
	set name  [lindex $args 0]
	set value [join [lrange $args 1 end]]

	upvar #0 $server S
	msg_debug CSet: $server $sock $msgid $name $value ($S($name))

	set S(setting) $name

	if { [catch { set ::$S($name) $value }] } {
        puts "Can't set $S($name) : $::errorInfo"
	}

	set S(setting) {}
}

proc msg_cack { server sock msgid ack args } {
    msg_response $server $sock $msgid $ack $args  1
}
proc msg_cnak { server sock msgid ack args } {
    msg_response $server $sock $msgid $ack $args -1
}
proc msg_timeout { server msgid } {
    msg_response $server nosock $msgid timeout {} -5
}
proc msg_response { server sock msgid ack args reply } {
    upvar #0 $server S
    msg_debug C$ack: $server $msgid $args

    set arg [join $args]

    if { [info exists S(cb,$msgid)] && [string compare $S(cb,$msgid) {}] } {
        if { [catch { set S(id,$msgid) [eval $S(cb,$msgid) $server $sock $msgid $ack $args] } reply] } {
            puts $reply
            set S(id,$msgid) -5
        }
        if { ![string compare $S(sy,$msgid) async] } {
            unset S(id,$msgid)
        }
    } else {
        set S(id,$msgid) "$reply $arg"
    }

    catch { unset S(cb,$msgid) }
    catch { unset S(sy,$msgid) }

    catch { after cancel $S(to,$msgid)
            msg_debug C$ack Timeout Canceled: $S(to,$msgid)"
            catch { unset S(to,$msgid) }
    }
}

proc msg_nak { sock msgid args } {
    msg_debug Nak: $sock $msgid $args
    if { $msgid != 0 } {
        msg_puts $sock $msgid nak $args

        if { [info exists ::MsgClientMap($sock)] } {
            msg_logmsg $::MsgClientMap($sock) $sock "nak" $msgid ack $args
        }
    }
}

proc msg_ack { sock msgid args } {
    msg_debug Ack: $sock $msgid $args
    if { $msgid != 0 } {
        msg_puts $sock $msgid ack [join $args]

        if { [info exists ::MsgClientMap($sock)] } {
            msg_logmsg $::MsgClientMap($sock) $sock "ack" $msgid ack $args
        }
    }
}

proc msg_rpy { sock msgid args } {
    msg_debug Rpy: $sock $msgid $args
    if { $msgid != 0 } {
        msg_puts $sock $msgid $args

        if { [info exists ::MsgClientMap($sock)] } {
            msg_logmsg $::MsgClientMap($sock) $sock "rpy" $msgid ack $args
        }
    }
}
proc msg_apikey { server keys } {
    upvar #0 $server S
    set S(__apikey) $keys
}

proc msg_getkey { server sock } {
    upvar #0 $server S
    return $S($sock,apikey)
}

proc msg_security { server peer sock } {
    upvar #0 $server S

    if { $S(__apikey) ne "" } {
        after 100
        set apikeys $S(__apikey)

        set 6 [read $sock 6]
        if { $6 ne "0 api " } {
            msg_debug apikey expected got $6
            return false
        }
        set apikey [read $sock [string length [lindex $apikeys 0]]]

        if { $apikey ni $apikeys } {
            puts "apikey no match : $apikey"
            return false
        }
        set S($sock,apikey) $apikey
        msg_debug apikey OK
    }

    msg_checkhost $peer $S(hosts.allow) $S(hosts.deny)
}

proc msg_checkhost {hostname allow deny} {
    set host [string tolower $hostname]
    for {set i 0} {$i <= [expr [llength $allow] - 1]} {incr i 1} {
        if {[msg_matchone $host [lindex $allow $i]] == 1} {
            return 1
        }
    }
    for {set j 0} {$j <= [expr [llength  $deny] - 1]} {incr j 1} {
        if {[msg_matchone $host [lindex  $deny $j]] == 1} {
            return 0
        }
    }
    return 1
}


proc msg_matchone {hostname pattern} {

        set host [split $hostname .]
        set pat  [split $pattern .] 

        regsub {\*} $pat {.*} pat

	set lenpat  [llength $pat]
        set lenhost [llength $host]

    if {$lenhost < $lenpat} {
        return 0
    }
    if {$lenpat < $lenhost} {
        for {set c 0} {$c < [expr $lenhost - $lenpat]} {incr c 1} {
            set pat [linsert $pat 0 .]
        }
    }	
    for {set i $lenhost} {$i > 0} {incr i -1} {
        set j [expr $i - 1]  
        set phost [lindex $host $j]
        set ppat [lindex $pat $j]
        if ![regexp ^$ppat$ $phost] {
            if {$ppat == "."} {
                return 1
            } else {
                return 0
            }
        }
    }
    return 1
}


proc msg_accept { server sock addr port } {
	upvar #0 $server S

    fconfigure $sock -buffering line -blocking no

    set peer [lindex [fconfigure $sock -peername] 1]
    set S($sock) $peer
    set S($sock,tag) -

    set ::MsgClientMap($sock) $server

    msg_debug New Client from $peer

    if { [msg_security $server $peer $sock] == 1 } {
        fileevent $sock readable "msg_handle $server $sock"
        set S($sock,tag) -
        msg_logmsg $server $sock "new"
    } else {
        msg_debug Kil Client no permission for $peer
        msg_logmsg $server $sock "nak" "permission denied"
        close $sock
    }
}

proc msg_init { server address type } {
	global env
	upvar #0 $server S


    if { [string compare $address {}] == 0 } {
        set name [string toupper $env($server)]
    } else {
        set name $address
    }

    set host [lindex [split $name : ] 0]
    if { [string compare $host "."] == 0 } {
        set host [info hostname]
    }
    set port [lindex [split $name : ] 1]

    set S(server)	$server
    set S(up) 		    0
    set S(connection) Down
    set S(timeout) 	 5000
    set S(reopen)  	 5000
    set S(hosts.allow) $host
    set S(hosts.deny)  { * }
    set S(__apikey)      {}
    set S(logfile)      NULL
    set S(logname)      NULL
    set S(N) 		$type

    set S(type) 	$type
    set S(host) 	$host
    set S(port) 	$port
    
    set S(setting)	{}

    msg_debug Init: $server name: $name host: $host port: $port

    catch { interp delete $server }
    #interp create -safe $server
    interp create $server
}

proc msg_down { server } { 
	upvar #0 $server S

    set sock $S(sock)
    close $sock

    set clients ""
    catch { set clients $S(+$name) }

    foreach sock $clients {
        close $sock
    }
}

proc msg_up { server } { 
	msg_debug Up: $server
	upvar #0 $server S

    set msginit .
    catch { set msginit $::env(MSGINITDIR) }
    catch { set msginit $::env(MSGINIT) }

    if { [file exists $msginit/[string tolower $server].rc] } {
	msg_debug $server "run $msginit/[string tolower $server].rc"
	msg_fakclient $server $msginit/[string tolower $server].rc
    } else {
	msg_debug $server "$msginit/[string tolower $server].rc not found"
    }

    set port $S(port)
    set S(sock) [socket -server "msg_accept $server" $port]
}

proc msg_isup { server } {
	upvar #0 $server S

	return $S(up)
}

proc msg_unknown { command server sock msgid args } {
	puts "msg unknown $args"
	msg_nak $sock $msgid "$server : unknown command : $msgid $command $args"
}

proc msg_date {} {
	clock format [clock seconds] -format "%Y%m%d.%T"
}

proc msg_server { server { address {} } { log {} } } {
    upvar #0 $server S
    global msg_logger
    msg_init $server $address 2
    msg_log $server $log
    
    interp eval $server rename set \{\}
    interp alias $server tag    {} msg_stag
    interp alias $server set    {} msg_sset
    interp alias $server get    {} msg_sget
    interp alias $server lst    {} msg_slst
    interp alias $server sub    {} msg_ssub
    interp alias $server ack    {} msg_sack
    interp alias $server log    {} msg_slog
    interp alias $server source {} msg_ssource
    interp alias $server spargs {} msg_srvproc_arglst

    interp alias $server unknown {} msg_unknown

    msg_publish $server log msg_logger
}

proc msg_client { server { init { } } { done { } } { address {} } } {
	upvar #0 $server S

    if { [info exists ::$server] } {
        puts stderr "Global variable $server exists : cannot open client connection"
        return
    }
    msg_init $server $address 1

    set S(init) $init
    set S(done) $done
    set S(sock) ""
    set S(+subs) ""
    set S(+vars) ""

    interp eval $server rename set _set
    interp alias $server set {} msg_cset
    interp alias $server ack {} msg_cack
    interp alias $server blk {} msg_cack
    interp alias $server nak {} msg_cnak

    set S(reopen_timer) [after idle [list msg_reopen $server]]
}

# Server side access control
#
proc msg_allow { server allow } {
	upvar #0 $server S

    set S(hosts.allow) $allow
}
proc msg_deny { server deny } {
	upvar #0 $server S

    set S(hosts.deny)  $deny
}

# Server side bindings
#
proc msg_register { server command { comment {} } { proc {} } } {
    if { ![string compare $proc {}] } { set proc $server.$command }

    upvar #0 $server S

    set S(R,$command) $comment
    $server alias $command $proc
}

proc msg_publish { server name { var {} } { code {} } { comment {} } } {
	upvar #0 $server S

    if { $var == {} } { set var $name }

    if { [info exists S($name)] } {
        puts "msg warning $name already published from $var"
        return
    }

    set S($name)       $var
    set S(+$name)      {}
    set S($name,cache) {}
    set S(P,$name) $comment


    upvar #0 $var v

    if { ![info exists ::$var] } {
        set ::$var {}
    }
    if { [string compare $code {}] != 0 } {
        trace variable v rw $code
    }
    trace variable v w "msg_postvar $server $name"

    msg_debug  "publish	$name from $var"
}

proc msg_published { server name } {
    upvar #0 $server S
    return $S($name)
}

proc msg_postvar { server name var index op } {
    msg_post $server $name
}

# Lowest level output
#
proc msg_puts { sock args } {
        msg_alarm $sock 3
        if { [catch { puts  $sock [join $args] } reply] } { close $sock }
        msg_alarm $sock 0
}

proc msg_setvar { server name code timeout sync variable indx op } {
	upvar #0 $server S 
	upvar $variable value

    if { [string compare $name $S(setting)] } {
	if { $S(up) == 1 } {
	    if { $op == "r" } {
		set value [msg_get $server ${name} $timeout $sync]
	    }
	    if { $op == "w" } {
		msg_set $server ${name} $value $timeout $sync
	    }
	}
    } else {
	if { [string compare $code {}] } {
	   uplevel #0 $code $variable $indx $op
	}
    }
}

proc msg_variable { server name var mode 
			{ def 0 } 
			{ init {} }
			{ code {} } 
			{ timeout {} }
			{ sync sync }
		  } {
	upvar #0 $server S

	global    $var 
	upvar #0  ${var}   v

	if { [info exists  v] == 0 } { 
	    set $var $def
	}

	set S($var) $name
	set S($var,value) $v

	lappend S(+vars) [list $var $name $init]
	if { $S(up) } {
	    if { ![string compare $init Server]
	      || ![string compare $init Up] } {
		set $S(setting) $name
		set $var [msg_get $server $name]
		set $S(setting) {}
	    }
	}

	trace variable $var $mode [list msg_setvar $server $name $code $timeout $sync]
}

proc msg_mapvar { server Map } {
 foreach m $Map {
        set var  [lindex $m 0]
        set name [lindex $m 1]
        set def  [lindex $m 2]
        set init [lindex $m 3]

	if { [string compare $init {}] == 0 } {
	    set init Up
	}
 
	msg_variable $server $name $var rw $def $init
 }
}

proc msg_log {server log} {
    upvar #0 $server S
    if { [string compare $log {} ] != 0 } {
        if { [file exists $log] } {
            set S(logname) $log
            set S(logfile) [open $log a]
            fconfigure $S(logfile) -buffering line
        }
    }
}

proc msg_logmsg {server sock type args} {
    upvar #0 $server S

    if { $S(type) == 1 } { return } 

    global msg_logger

    set date [msg_date]

    if { [string compare $S(logfile) NULL] != 0} {
	puts $S(logfile) $msg_logger
    }
    set msg_logger "$date $server $S(host):$S(port) $S($sock) $S($sock,tag) $type $args"
}

#
# Enhancements to msg.tcl to impliment subscription value
# caching and update as the C server does.
#
proc msg_ssub { server sock msgid sub name { update 1 } } {
	msg_debug SSub: $server $sock $msgid $name
	upvar #0 $server S

	if { [catch {
            upvar #0 $S($name) var

	    if { [string compare $S($name) {}] == 0 } {
            error "No variable $name"
            return
	    } }] == 1 } {
            error "No variable $name"
        }

    lappend S(+$sock) $name ; set S(+$sock) [lsort -unique $S(+$sock)]
	lappend S(+$name) $sock ; set S(+$name) [lsort -unique $S(+$name)]

	set S($name,$sock,update) [expr int($update * 1000)]
	set S($name,$sock,lastup) [clock clicks -milliseconds]
	set S($name,$sock,after)  {}

	if { $update < 0 } {
	    set S($name,$sock,after) [after [expr -($update)] \
			"msg_postafter $server $sock $name"]
	}

	msg_ack $sock $msgid $name $var
}

proc msg_postafter { server sock name } {
	upvar #0 $server S
	upvar #0 $S($name) var

	msg_debug PstA: $server $sock $name $var

	if { [catch {
	    msg_puts $sock 0 set $name $var
	    set S($name,$sock,lastup) [clock clicks -milliseconds]
	} reply] } { puts $reply }

	msg_debug PstB: $server $sock $name $var

	set update $S($name,$sock,update)

	if { $update < 0 } {
	    set S($name,$sock,after) [after [expr -($update)] \
			"msg_postafter $server $sock $name"]
	} else {
	    set S($name,$sock,after) {}
	}
}

proc msg_post { server name { post 1 } } {
	upvar #0 $server S
	upvar #0 $S($name) var

    msg_debug Post: $name $var

    set change [string compare $S($name,cache) $var]
    set clock  [clock clicks -milliseconds]
    set S($name,cache) $var


    foreach sock $S(+$name) {
        if { ![string compare $sock $::MsgSetting] } {
            set S($name,$sock,lastup) $clock
            continue
        }

        set update $S($name,$sock,update)

        msg_debug Not Skipped Post: $sock $name $var : Update $update Change $change After  $S($name,$sock,after)
        if { $update > 0				\
          && $change					\
          && ![string compare $S($name,$sock,after) {}] } {

            set nextup [expr ($S($name,$sock,lastup)	\
                        + $S($name,$sock,update)) - $clock]

            if { $nextup < 0 } { set nextup 0 }

            set S($name,$sock,after) [after $nextup 	\
                "msg_postafter $server $sock $name"]
            if { "$name" != "log" } {
            msg_logmsg $server $sock set $name $var
            }
        }
        if { $post && $update == 0 } {
            catch {
                msg_puts $sock 0 set $name $var
            if { "$name" != "log" } {
                msg_logmsg $server $sock set $name $var
            }
                set S($name,$sock,lastup) $clock
            }
        }
    }
}

proc msg_kilclient { server sock } {
    msg_debug Kil Server $server $sock

    upvar #0 $server S

    catch { unset ::MsgClientMap($sock) }

    msg_logmsg $server $sock "kil"
    foreach timer [array names S to,*] {
    	catch { after cancel $S($timer) }
        unset S($timer)
    }
    foreach msgid [array names S {id,[0-9]*}] {
    	catch { set S($msgid) -3 }
    }
    if { [info exists S(+$sock)] } {
        foreach name $S(+$sock) {
            set ix [lsearch -exact $S(+$name) $sock]
            set S(+$name) [lreplace $S(+$name) $ix $ix]

            catch { after cancel $S($name,$sock,after) }

            catch { array unset S($name,$sock,update) }
            catch { array unset S($name,$sock,lastup) }
            catch { array unset S($name,$sock,after)  }
        }
        catch { array unset S(+$sock) }
    }
}

proc rx { exp str rep } {
     regsub -all -- $exp $str $rep rx
     return $rx
}

proc msg_srvproc { server name args body } {
    if { [llength $name] == 2 } {
        set proc [lindex $name 1]
        set name [lindex $name 0]
    } else {
        set proc $name
    }

    msg_register $server $name {} $server.$proc

    proc $proc $args $body
    set a {}
    foreach arg $args { lappend a [lindex $arg 0] }

    catch { if { [lindex $a end] eq "args" } { set a [join [lreplace $a end end "{*}args"]] }  }	; # This makes is work for 8.5+ and a nop for 8.4

    proc $server.$proc [concat s sock msgid cmd $args] [subst {
        msg_ack \$sock \$msgid \[[concat $proc [rx {([_a-zA-Z0-9]+)} $a {$\1}]]]
    }]
}

proc msg_fakclient { server file } {
	upvar #0 $server S

    set fake [open $file r]

    set S($fake) $file
    set S($fake,tag) -
    fconfigure $fake -buffering line
    fileevent $fake readable "msg_handle $server $fake"
}

proc msg_srvproc_arglst {server sock msgid spargs procname} {
	msg_debug SPArgs: $server $sock $msgid $procname
	set arglst ""
	set pname  ${server}.$procname

	# if procname not defined, nak
	if ![llength [info procs $pname]] {
		msg_nak $sock $msgid "srvproc $procname not defined"
		return
	}

	# get arguments, reconstruct default values
	foreach arg [info args $pname] {
		if [info default $pname $arg X] {
			lappend arglst [list $arg $X]
		} else {
			lappend arglst $arg
		}
	}

	# return complete (+ defaults) argument list
	msg_ack $sock $msgid [list $arglst]
}

proc msg_cliproc { server procname {retdef false} {timeout ""} } {
	msg_debug CliProc: $server $procname

	# get arguments for this server-side proc
	set args [msg_cmd $server "spargs $procname"]
	regexp {^s sock msgid cmd (.*)$} $args -> args

	# generate $<argname> for the local body
	foreach arg $args {
		set arg [lindex $arg 0]
		lappend dargs "\$$arg"
	}
	set body [subst -nocommands {
		return [msg_cmd $server "$procname $dargs" $timeout]
	}]

	# make/return the local (copy) procedure
	set procdef [list proc $procname $args $body]

	if $retdef {
		return $procdef
	} else {
		uplevel $procdef
	}
}

proc msg_cliproc_all { server } {
	msg_debug CliProcAll: $server

	set newprocs ""

	# run through list of server defines
	msg_list $server lst
	foreach defn $lst {

		# grab type and name of definition
		set type [lindex $defn 0]
		set name [lindex $defn 1]

		# if it's not registered (a proc), skip
		if ![string equal $type "registered"] \
			continue

		# grab and run a cliproc definition
		lappend newprocs $name
		uplevel [msg_cliproc $server $name true]
	}

	# return list of defined (copy) procedures
	return $newprocs
}
