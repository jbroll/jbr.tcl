
package require TclOO

package require jbr::unix
package require jbr::tcloo
package require jbr::print

oo::class create logger {

    constructor { { _level info } { files - } { _logpath . } } {
        variable levels { fatal error warn info debug } 

        variable level 
        variable files
        variable logpath
        variable lineFormat
        variable fileFormat
        
        set level [lsearch $levels $_level]
        set files $_files
        set logpath $_logpath
        set lineFormat {$date $time $file:$line $msg} 
        set fileFormat {$path/$date-$file.log}
    }
    
    private method levelValue { l } {
        variable levels
        return [lsearch $levels $l]
    }

    private method log { msgLevel msg } {
        variable level

        if { $level >= $msgLevel} {
            variable files
            variable lineFormat
            variable fileFormat

            set frame [info frame -2]
            set path [dict get $frame file]
            set file [file tail $path]
            set line [dict get $frame line]
            set date [clock format [clock seconds] -format "%Y%m%d"]
            set time [clock format [clock seconds]]

            set msg [subst $lineFormat]

            set path $logpath
            foreach file $files {
                set log [subst $fileFormat]
                print echo $msg >> $log
            }
        }
    }

    public method info  { msg } { my log 3 $msg }
    public method warn  { msg } { my log 2 $msg }
    public method error { msg } { my log 1 $msg }
    public method error-info { msg } { my log 1 $msg; my log 1 $::errorInfo }
    public method level { l } { 
        set level [my levelValue $l]
    }
    public files { _files } {
        variable files
        set files $_files
    }
    public path { _path } {
        variable path
        set path $_path
    }
}
	
logger create log
