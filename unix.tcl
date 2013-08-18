
proc timer { name action } {
    if { ![info exists ::timer($name,timer)] } { set ::timer($name,timer) 0 }

    switch $action {
	clear { set ::timer($name,timer) 0 }
	start { set ::timer($name,start) [clock milliseconds] }
	stop  { set ::timer($name,timer) [expr $::timer($name,timer) + [clock milliseconds] - $::timer($name,start)] }
    }

    format %.2f [expr $::timer($name,timer)/1000.0]
}

proc sleep { timer } {
    set sleepvar [namespace current]::sleep[clock seconds][expr int(rand() * 1000)]
    after $timer [list set $sleepvar 0]
    vwait $sleepvar
    unset $sleepvar
}

proc K { x y } { set x }
proc touch file {close [open $file a]}
proc cat { file } {
    if { [K [read [set fp [open $file rb]] 2] [close $fp]] eq "\xFF\xFE" } {
	return [string range [K [read -nonewline [K [set fp [open $file]] [fconfigure $fp -encoding unicode]]] [close $fp]] 1 end]
    } else {
	return [K [read -nonewline [K [set fp [open $file]] [fconfigure $fp -encoding utf-8]]] [close $fp]]
    }
}
proc echo { string { redirector - } { file - }} {
    switch -- $redirector {
	>       { set fp [open $file w]	}
	>>      { set fp [open $file a]	}
	default { set fp stdout		}
    }

    puts $fp $string
    if { [string compare $file -] } { close $fp }
}
proc file-lock { lock { timer 0 } } {
   incr timer [clock seconds]
   echo [pid] > $lock.[pid]

   incr timer [clock seconds]
   while { 1 } {
	if { ![catch {
		file link -hard $lock.lock $lock.[pid]
		file del $lock.[pid] }] } {
	    file del $lock.[pid]
	    return
	}

	set lpid [cat $lock.lock]

	if { $lpid == [pid] } {
	    file del $lock.[pid]
	    error "pid [pid] locks $lock twice"
	}

	if { [catch { exec kill -0 $lpid } reply] } {
	    file del $lock.lock
	    if { ![catch {
		    file link -hard $lock.lock $lock.[pid]
		    file del $lock.[pid] }] } {
	        file del $lock.[pid]
		return
	    }
	}

        if { [clock seconds] > $timer } {
	    file del $lock.[pid]
            error "cannot aquire lock $lock"
        }
        sleep 200
    }
}
proc file-unlock { lock } {
    if { [cat $lock.lock] != [pid] } {
	error "pid [pid] tries to unlock $lock: locked by [cat $lock.lock]!"
    }

    file del $lock.lock
}
