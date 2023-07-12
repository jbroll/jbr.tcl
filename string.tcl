
proc ::tcl::string::ends-with { str suffix } { 
    set len [expr { [string length $suffix] -1 }]

    return [string equal [string range $str end-$len end] $suffix]
}
namespace ensemble configure string -map [dict merge [namespace ensemble configure string -map] {ends-with ::tcl::string::ends-with}] 

proc ::tcl::string::starts-with { str prefix } { 
    set len [expr { [string length $prefix] -1 }]

    return [string equal [string range $str 0 $len] $prefix]
}
namespace ensemble configure string -map [dict merge [namespace ensemble configure string -map] {starts-with ::tcl::string::starts-with}] 

proc ::tcl::string::chunk { data { size 70 } } { 
    set len [expr { $size -1 }]

    for { set i 0 } { $i < [string length $data] } { incr i $size } {
	lappend reply [string range $data $i $i+$len]
    }

    set reply
}
namespace ensemble configure string -map [dict merge [namespace ensemble configure string -map] {chunk ::tcl::string::chunk}] 

# AMG https://wiki.tcl-lang.org/page/string+insert
#
# Pure Tcl implementation of [string insert] command.
proc ::tcl::string::insert {string index insertString} {
    # Convert end-relative and TIP 176 indexes to simple integers.
    if {[regexp -expanded {
        ^(end(?![\t\n\v\f\r ])      # "end" is never followed by whitespace
        |[\t\n\v\f\r ]*[+-]?\d+)    # m, with optional leading whitespace
        (?:([+-])                   # op, omitted when index is "end"
        ([+-]?\d+))?                # n, omitted when index is "end"
        [\t\n\v\f\r ]*$             # optional whitespace (unless "end")
    } $index _ m op n]} {
        # Convert first index to an integer.
        switch $m {
            end     {set index [string length $string]}
            default {scan $m %d index}
        }

        # Add or subtract second index, if provided.
        switch $op {
            + {set index [expr {$index + $n}]}
            - {set index [expr {$index - $n}]}
        }
    } elseif {![string is integer -strict $index]} {
        # Reject invalid indexes.
        return -code error "bad index \"$index\": must be\
                integer?\[+-\]integer? or end?\[+-\]integer?"
    }

    # Concatenate the pre-insert, insertion, and post-insert strings.
    string cat [string range $string 0 [expr {$index - 1}]] $insertString\
               [string range $string $index end]
}
# Bind [string insert] to [::tcl::string::insert].
namespace ensemble configure string -map [dict replace\
        [namespace ensemble configure string -map]\
        insert ::tcl::string::insert]

