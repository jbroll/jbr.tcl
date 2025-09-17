
package require jbr::print

proc filewatch { file command { interval 5000 } {mtime -} } {
    if {$mtime eq "-"} {
        if [info exists ::_twf:$file] {after cancel [set ::_twf:$file]}
        filewatch $file $command $interval [file mtime $file]
    } else {
        set newtime [file mtime $file]
        if {$newtime != $mtime} {
            try $command on error e { 
                print filewatch $file $e 
                error $e
            }
            filewatch $file $command $interval [file mtime $file]
        } else {
            set ::_twf:$file [after $interval [info level 0]]
        }
    }
}

