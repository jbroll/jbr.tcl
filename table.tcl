
namespace eval table {
    namespace export header body row col nth todict tolist colnum setcell getcell justify rows cols
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
        set hdr [lselect [tbl header] $indicies]
        set bdy [map row [body $tbl] { lselect $row $indicies }]
        list $hdr {*}$bdy
    }
    proc colnum { tbl colname } {
        set header [header $tbl]
        lsearch $header $colname
    }
    proc nth { tbl row } {
        return [list [lindex $tbl 0] [lindex $tbl $row+1]]
    }
    proc todict { tbl } {
        return [zip [lindex $tbl 0] [lindex $tbl 1]]
    }
    proc tolist { tbl } {
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
    proc cols { tbl } {
        llength [lindex $tbl 0]
    }
    proc rows { tbl } {
        llength $tbl
    }

    proc justify { tbl } {

        foreach i [iota [table cols $tbl]-1] { set $i 0 }
        foreach row $tbl {
            foreach i [iota [llength $row]-1] col $row {
                set $i [expr { max([set $i], [string length $col]) }]
            }
        }
        set format [join [map i [iota [table cols $tbl]-1] { I "%[set $i]s" }] " "]
        
        join [map row $tbl { format $format {*}$row }] \n
    }
}

