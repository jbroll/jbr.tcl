

proc _execbg { file } {
    upvar #0 $file F

    if { [eof $file] } {
        global $F(waitName)

        if { [string compare $F(dataName) {}] } {
            global $F(dataName)
            global $F(incrName)

            if { ![string compare $F(trim) {}] } {
                set $F(dataName) $F(incrName)
            } else {
                set $F(dataName) [string $F(trim) [set $F(incrName)]]
            }
        }

        close $file

        if { [file size $F(errFile)] } {
            if { [string compare $F(errName) {}] } {
                global $F(errName)

                set efile [open $F(errFile)]

                if { ![string compare $F(trim) {}] } {
                    set $F(errName) [read $efile]
                } else {
                    set $F(errName) [string $F(trim) [read $efile]]
                }
                close $efile
            }
            set $F(waitName) 1
        } else  {
            set $F(waitName) 0
        }
        file delete $F(errFile)
    } else {
        global $F(incrName)

        if { [string compare $F(incrName) {}] } {
            append $F(incrName) [read $file]
        } else {
            puts -nonewline [read $file]
        }
    }
}

set execbg 1

proc execbg { waitName args } {
    global $waitName
    global execbg

    while { [file exists [set errFile "/tmp/execbg[incr execbg].err"]] } { }

    set  errName {}
    set dataName {}
    set incrName {}

    set trim	 trim
    set trap	 0
    set wait	 0

    set eoo 0
    set command |
    for { set i 0 } { $i < [llength $args] } { incr i } {
        set arg [lindex $args $i]

        if { !$eoo } {
            switch -regexp -- $arg {
            -keepnewline 	{ set trim {} }
            -trim 	        { set trim     [lindex $args [incr i]] }
            -output 	{ set dataName [lindex $args [incr i]] }
            -onoutput 	{ set incrName [lindex $args [incr i]] }
            -error 		{ set  errName [lindex $args [incr i]] }
            -- 		{ set eoo  1 }
            -trap		{ set trap 1 }
            -wait		{ set wait 1 }
            "-.*" 		{
                error "execbg: unknown option: $arg"
            }
            ".*" {
                lappend command $arg
                    set eoo 1
            }
            }
        } else {
            lappend command $arg
        }
    }

    lappend command 2> $errFile

    print $command
    set file [open $command r]
    global $file

    if { [string compare $dataName {}] } {
    	global $dataName;  set $dataName {}

        if { ![string compare $incrName {}] } {
            set incrName _$dataName
        }
    }
    if { [string compare $incrName {}] } {
        global $incrName;  set $incrName {}
    }

    set ${file}(waitName) $waitName
    set ${file}(dataName) $dataName
    set ${file}(incrName) $incrName

    set ${file}(errFile)  $errFile
    set ${file}(errName)  $errName

    set ${file}(trim)	  $trim
    set ${file}(trap)	  $trap

    fconfigure $file -translation binary -blocking no
    fileevent $file r [list _execbg $file]

    if { $wait } {
        if { $trap && ![string compare $errName {}] } {
            set errName [set ${file}(errName) $errFile]
        }
        vwait $waitName
        if { $trap && [set ::$waitName] } {
            set err [set ::$errName]

            catch { unset ::${file}(errFile) }
            error $err
        }
    } else {
        return [pid $file]
    }
}

if { 0 } {
    set data {}
    execbg data -output wink runme zero dink

    vwait data
    puts "output: $wink"
    puts "status: $data"
    if { $data } { puts $errs }
}
