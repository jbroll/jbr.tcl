
proc lsplit { list aName bName { on -> } } {
    upvar $aName a
    upvar $bName b

    set indx [lsearch $list $on]
    if { $indx < 0 } {
        set a $list
        set b {}
    } else {
        set a [lrange $list 0 $indx-1]
        set b [lrange $list $indx+1 end]
    }
}

