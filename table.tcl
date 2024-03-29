
namespace eval table {
    namespace export header body row col nth todict tolist colnum setcell getcell justify nrow ncol
    namespace export foreachrow sort colapp compute rowdict

    namespace ensemble create

    proc header { tbl } {
        lindex $tbl 0
    }
    proc body { tbl } {
        lrange $tbl 1 end
    }
    proc row { tbl args } {
        set header [header $tbl]
        foreach vname [lrange $args 0 end-1] {
            lassign $vname v _v
            if { $_v eq "" } { set _v $v }
            upvar 1 $v $_v
        }
        set expr [lindex $args end]
        set bdy [map row [body $tbl] [% {
            lassign %row {*}%header
            if { !($expr) } { continue };  set row 
        }]]
        list $header {*}$bdy
    }
    proc col { tbl args } {
        set header [header $tbl]
        set indicies [map i $args { lsearch $header $i }]
        set hdr [lselect $header {*}$indicies]
        set bdy [map row [body $tbl] { lselect $row {*}$indicies }]
        list $hdr {*}$bdy
    }
    proc ncol { tbl } { llength [lindex $tbl 0] }
    proc nrow { tbl } { llength $tbl }

    proc sort { tbl cols args } {
        set header [header $tbl]
        set indicies [map i $cols { lsearch $header $i }]
        list $header {*}[lsort {*}$args -index $indicies [body $tbl]]
    }

    proc colapp { tbl col } {
        list [list {*}[header $tbl] $col] {*}[map row [table body $tbl] { list {*}$row {} }]
    }
    proc foreachrow { tbl rowName { script {} } } {
        if { $script eq "" } {
            set script $rowName
            set rowName row
        }
        upvar $rowName row

        foreach row [table body $tbl] {
            uplevel "lassign \$row [table header $tbl] ; " $script
        }
    }

    proc compute { tbl { script {} } } {
        set header [header $tbl]
        set setvars "list [join [map col $header { I \$$col }] " "]"
        list $header {*}[map row [body $tbl] {
            uplevel [list lassign $row {*}$header]
            uplevel $script
            uplevel $setvars
        }]
    }

    proc colnum { tbl colname } {
        lsearch [header $tbl] $colname
    }
    proc nth { tbl row } {
        return [list [lindex $tbl 0] [lindex $tbl $row+1]]
    }
    proc rowdict { tbl } {
        if { [llength $tbl] != 2 } {
            error "a table of more than one row cannot convert ta a dict"
        }
        return [zip [lindex $tbl 0] [lindex $tbl 1]]
    }
    proc todict { tbl } {
        if { [table ncol $tbl] != 2 } {
            error "a table of 2 columns is required to convert ta a dict : [table ncol $tbl]"
        }
        set dict {}
        foreach row [table body $tbl] {
            lassign $row 1 2
            lappend dict $1 $2
        }
        return $dict
    }
    proc tolist { tbl } {
        if { [llength $tbl] != 2 } {
            error "a table of more than one row cannot convert ta a list"
        }
        return [lindex $tbl 1]
    }
    proc cell { tbl row col } {
        return [lindex [lindex $tbl $row+1] $col]
    }
    proc getcell { tbl row col } {
        lindex $tbl $row+1 $col
    }
    proc setcell { tbl row col value } {
        uplevel 1 "lset $tbl $row+1 $col [list $value]"
    }

    proc justify { tbl } {

        foreach i [iota [table ncol $tbl]] { set $i 0 }
        foreach row $tbl {
            foreach i [iota [llength $row]] col $row {
                set $i [expr { max([set $i], [string length $col]) }]
            }
        }
        set format [join [map i [iota [table ncol $tbl]] { I "%[set $i]s" }] " "]
        
        join [map row $tbl { format $format {*}$row }] \n
    }
}

