
package require TclOO

set HOME $env(HOME)
::tcl::tm::path add $HOME/lib/tcl8/site-tcl

package require jbr::unix
package require jbr::tcloo
package require jbr::print

set APPNAME [file rootname [file tail $::argv0]]

oo::class create logger {

    constructor { { l info } } {
	variable levels { fatal error warn info debug } 

	variable level 
	variable files
	variable lineFormat
	variable fileFormat
	
	set level [lsearch $levels $l]
	set files [list LOGFILE - ]
	set lineFormat {$time $file:$line $msg} 
	set fileFormat {$date-$name.log}
    }
    
    private method levelValue { l } {
	classvariable levels
	return [lsearch $levels $l]
    }

    private method log { msgLevel msg } {
	variable level
	variable files
	variable lineFormat
	variable fileFormat

	if { $level >= $msgLevel } {
	    set frame [info frame -2]
	    set path [dict get $frame file]
	    set file [file tail $path]
	    set line [dict get $frame line]
	    set date [clock format [clock seconds] -format "%Y%m%d"]
	    set time [clock format [clock seconds]]
	    set name $::APPNAME

	    set msg [subst $lineFormat]
	    set log [subst $fileFormat]
	    foreach file $files {
		print echo $msg >> $log
	    }
	}
    }

    public method info  { msg } { my log 3 $msg }
    public method warn  { msg } { my log 2 $msg }
    public method error { msg } { my log 1 $msg }
    public method level { l } { 
	set level [my levelValue $l]
    }
}
	

logger create log
