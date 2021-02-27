
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


# https://wiki.tcl-lang.org/page/lselect : Larry Smith
#
# Returns from the specified list one or more elements identified by given indices.
# The first element in list is given by index 0, the last element of list is given by "end".
# An optional negative offset (e.g. "end-1") can be used to specify elements relative to the end of list.
# The list to operate on is passed by listval.
proc lselect {listval args} {
   set result {}
   if {[llength $listval]>0} {
      foreach index $args {
         lappend result [lindex $listval $index]
      }
   }
   return $result
}
