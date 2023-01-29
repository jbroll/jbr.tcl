
set APPNAME [file rootname [file tail $::argv0]]
set LOGFILE [clock format [clock seconds] -format "%Y%m%d"]-$APPNAME.log

proc log { msg } {
    echo $msg >> $::LOGFILE
}

