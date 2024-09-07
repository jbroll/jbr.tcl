# https://wiki.tcl-lang.org/page/Alternative+JSON
#
namespace eval ::json {}

# ::json::encode --
# Encodes data in the JSON format per https://tools.ietf.org/html/rfc7159.
proc ::json::encode {data} {
    # Extract type and value from data argument.
    if {[llength $data] != 2} {
        error "invalid JSON data: must be a two-element list consisting of\
                type and value"
    }
    lassign $data type value

    # Extract top and subtype from type element.
    set toptype [lindex $type 0]
    if {[llength $type] >= 2} {
        if {[llength $type] == 2} {
            set subtype [lindex $type 1]
        } else {
            set subtype [lrange $type 1 end]
        }
        if {$toptype ni {array object}} {
            set toptype {}
        }
    }

    # Perform type-specific JSON encoding.
    switch $toptype {
    array {
        # Recursively encode each array element.  If a subtype was specified, it
        # is shared between all elements.  Otherwise, each element is itself a
        # two-element list consisting of type and value.
        set comma {}
        set result \[
        foreach element $value {
            append result $comma
            set comma ,
            if {[info exists subtype]} {
                append result [encode [list $subtype $element]]
            } else {
                append result [encode $element]
            }
        }
        append result \]
        return $result
    } object {
        if { $value == "null" } {
            return null
        }

        # Recursively encode each object key and element.  Keys are always
        # strings.  If a subtype was specified, it is shared between all
        # elements.  Otherwise, each element is itself a two-element list
        # consisting of type and underlying data value.
        set comma {}
        set result \{
        foreach {key element} $value {
            append result $comma
            set comma ,
            append result [encode [list string $key]] :
            if {[info exists subtype]} {
                append result [encode [list $subtype $element]]
            } else {
                append result [encode $element]
            }
        }
        append result \}
        return $result
    } string {
        if { $value == "null" } {
            return null
        }

        # Encode the minimal set of required escape sequences.
        return \"[string map {
            \x00 \\u0000    \x01 \\u0001    \x02 \\u0002    \x03 \\u0003
            \x04 \\u0004    \x05 \\u0005    \x06 \\u0006    \x07 \\u0007
            \x08 \\u0008    \x09 \\u0009    \x0a \\u000a    \x0b \\u000b
            \x0c \\u000c    \x0d \\u000d    \x0e \\u000e    \x0f \\u000f
            \x10 \\u0010    \x11 \\u0011    \x12 \\u0012    \x13 \\u0013
            \x14 \\u0014    \x15 \\u0015    \x16 \\u0016    \x17 \\u0017
            \x18 \\u0018    \x19 \\u0019    \x1a \\u001a    \x1b \\u001b
            \x1c \\u001c    \x1d \\u001d    \x1e \\u001e    \x1f \\u001f
            \\   \\\\       \"   \\\"
        } $value]\"
    } number {
        if { $value == "null" } {
            return null
        }

        # Attempt to normalize the number to comply with the JSON standard.
        regsub {^[\f\n\r\t\v ]+} $value {} result     ;# Strip leading space.
        regsub {[\f\n\r\t\v ]+$} $result {} result    ;# Strip trailing space.
        regsub {^\+(?=[\d.])} $result {} result       ;# Strip leading plus.
        regsub {^(-?)0+(?=\d)} $result {\1} result    ;# Strip leading zeroes.
        regsub {(\.\d*[1-9])0+} $result {\1} result   ;# Strip trailing zeroes.
        regsub {E} $result {e} result                 ;# Normalize exponent, 1.
        regsub {^(-?\d+)e} $result {\1.0e} result     ;# Normalize exponent, 2.
        regsub {\.e} $result {.0e} result             ;# Normalize exponent, 3.
        regsub {e(\d)} $result {e+\1} result          ;# Normalize exponent, 4.
        regsub {(^|-)\.(?=\d)} $result {\10.} result  ;# Prefix leading dot.
        regsub {(\d)\.(?=\D|$)} $result {\1.0} result ;# Suffix trailing dot.
        if {![regexp {^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][-+]?\d+)?$} $result]} {
            error "invalid JSON number \"$value\":\
                    see https://tools.ietf.org/html/rfc7159#section-6"
        }
        return $result
    } literal {
        if { $value == "null" } {
            return null
        }

        # The only valid literals are false, null, and true.
        if {$value ni {false null true}} {
            error "invalid JSON literal \"$value\":\
                    must be false, null, or true"
        }
        return $value
    } encoded {
        # Raw data.  The caller must supply correctly formatted JSON.
        return $value
    } decoded {
        # Nested decoded data.
        encode $value
    } default {
        # Invalid type.
        error "invalid JSON type \"$type\": must be array, object, string,\
                number, literal, encoded, decoded, or {array|object ?...?\
                subtype}, where subtype is recursively any valid JSON type"
    }}
}

# ::json::decode --
# Decodes data from the JSON format per https://tools.ietf.org/html/rfc7159.
# The optional indexVar argument is the name of a variable that holds the index
# at which decoding begins (defaults to 0 if the variable doesn't exist) and
# will hold the index immediately following the end of the decoded element.  If
# indexVar is not specified, the entire JSON input is decoded, and it is an
# error for it to be followed by any non-whitespace characters.
proc ::json::decode {json {indexVar {}}} {
    # Link to the caller's index variable.
    if {$indexVar ne {}} {
        upvar 1 $indexVar index
    }

    # By default, start decoding at the start of the input.
    if {![info exists index]} {
        set index 0
    }

    # Skip leading whitespace.  Return empty at end of input.
    if {![regexp -indices -start $index {[^\t\n\r ]} $json range]} {
        return
    }
    set index [lindex $range 0]

    # The first character determines the JSON element type.
    switch [string index $json $index] {
    \" {
        # JSON strings start with double quote.
        set type string

        # The value is the text between matching double quotes.
        if {![regexp -indices -start $index {\A\"((?:[^"\\]|\\.)*)\"}\
                $json range sub]} {
            return -code error "invalid JSON string at index $index:\
                    must end with close quote"
        }
        set value [string range $json {*}$sub]

        # Process all backslash substitutions in the value.
        set start 0
        while {[regexp -indices -start $start {\\u[[:xdigit:]]{4}|\\[^u]}\
                $value sub]} {
            set char [string index $value [expr {[lindex $sub 0] + 1}]]
            switch $char {
                u {set char [subst [string range $value {*}$sub]]}
                b {set char \b} f {set char \f} n {set char \n}
                r {set char \r} t {set char \t}
            }
            set value [string replace $value {*}$sub $char]
            set start [expr {[lindex $sub 0] + 1}]
        }
    } \{ - \[ {
        # JSON objects/arrays start with open brace/bracket.
        if {[string index $json $index] eq "\{"} {
            set type object
            set endRe {\A[\t\n\r ]*\}}
            set charName brace
        } else {
            set type array
            set endRe {\A[\t\n\r ]*\]}
            set charName bracket
        }
        set value {}
        incr index

        # Loop until close brace/bracket is encountered.
        while {![regexp -indices -start $index $endRe $json range]} {
            # Each element other than the first is preceded by comma.
            if {[llength $value]} {
                if {![regexp -indices -start $index\
                        {\A[\t\n\r ]*,} $json range]} {
                    return -code error "invalid JSON $type at index $index:\
                            element not followed by comma or close $charName"
                }
                set index [expr {[lindex $range 1] + 1}]
            }

            # For objects, get key and confirm it is followed by colon.
            if {$type eq "object"} {
                set key [decode $json index]
                if {![llength $key]} {
                    return -code error "invalid JSON object at index $index:\
                            must end with close brace"
                } elseif {[lindex $key 0] ne "string"} {
                    return -code error "invalid JSON object at index $index:\
                            key type is \"[lindex $key 0]\", must be string"
                } elseif {![regexp -indices -start $index {\A[\t\n\r ]*:}\
                        $json range]} {
                    return -code error "invalid JSON object at index $index:\
                            key not followed by colon"
                }
                set index [expr {[lindex $range 1] + 1}]
                lappend value [lindex $key 1]
            }

            # Get element value.
            lappend value [decode $json index]
        }
    } t - f - n {
        # JSON literals are true, false, or null.
        set type literal
        if {![regexp -indices -start $index {(?:true|false|null)\M}\
                $json range]} {
            return -code error "invalid JSON literal at index $index"
        }
        set value [string range $json {*}$range]
    } - - + - 0 - 1 - 2 - 3 - 4 - 5 - 6 - 7 - 8 - 9 - . {
        # JSON numbers are integers or real numbers.
        set type number
        if {![regexp -indices -start $index --\
               {\A-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][-+]?\d+)?\M} $json range]} {
            return -code error "invalid JSON number at index $index"
        }
        set value [string range $json {*}$range]
    } default {
        # JSON allows only the above-listed types.
        return -code error "invalid JSON data at index $index"
    }}

    # Continue decoding after the last character matched above.
    set index [expr {[lindex $range 1] + 1}]

    # When performing a full decode, ensure only whitespace appears at end.
    if {$indexVar eq {} && [regexp -start $index {[^\t\n\r\ ]} $json]} {
        return -code error "junk at end of JSON"
    }

    # Return the type and value.
    list $type $value
}

# ::json::schema --
# Extracts JSON type information from the output of [json::decode].
proc ::json::schema {data} {
    # Extract type and value from data argument.
    if {[llength $data] != 2} {
        error "invalid JSON data: must be a two-element list consisting of\
                type and value"
    }
    lassign $data type value

    # Extract top and subtype from type element.
    set toptype [lindex $type 0]
    if {[llength $type] >= 2} {
        if {[llength $type] == 2} {
            set subtype [lindex $type 1]
        } else {
            set subtype [lrange $type 1 end]
        }
        if {$toptype ni {array object}} {
            set toptype {}
        }
    }

    # Perform type-specific JSON processing.
    switch $toptype {
    array {
        list $toptype [lmap element $value {
            if {[info exists subtype]} {
                schema [list $subtype $element]
            } else {
                schema $element
            }
        }]
    } object {
        list $toptype [dict map {key element} $value {
            if {[info exists subtype]} {
                schema [list $subtype $element]
            } else {
                schema $element
            }
        }]
    } string - number - literal {
        return $toptype
    } encoded {
        schema [decode $value]
    } decoded {
        schema $value
    } default {
        error "invalid JSON type \"$type\": must be array, object, string,\
                number, literal, encoded, decoded, or {array|object ?...?\
                subtype}, where subtype is recursively any valid JSON type"
    }}
}

# ::json::values --
# Extracts JSON value information from the output of [json::decode].
proc ::json::values {data} {
    # Extract type and value from data argument.
    if {[llength $data] != 2} {
        error "invalid JSON data: must be a two-element list consisting of\
                type and value"
    }
    lassign $data type value

    # Extract top and subtype from type element.
    set toptype [lindex $type 0]
    if {[llength $type] >= 2} {
        if {[llength $type] == 2} {
            set subtype [lindex $type 1]
        } else {
            set subtype [lrange $type 1 end]
        }
        if {$toptype ni {array object}} {
            set toptype {}
        }
    }

    # Perform type-specific JSON processing.
    switch $toptype {
    array {
        lmap element $value {
            if {[info exists subtype]} {
                values [list $subtype $element]
            } else {
                values $element
            }
        }
    } object {
        dict map {key element} $value {
            if {[info exists subtype]} {
                values [list $subtype $element]
            } else {
                values $element
            }
        }
    } string - number - literal {
        return $value
    } encoded {
        values [decode $value]
    } decoded {
        values $value
    } default {
        error "invalid JSON type \"$type\": must be array, object, string,\
                number, literal, encoded, decoded, or {array|object ?...?\
                subtype}, where subtype is recursively any valid JSON type"
    }}
}

# ::json::unite --
# Combines the output of [json::schema] with the output of [json::values] to
# produce a suitable input for [json::encode].  The [json::schema] input format
# is extended to allow variable-length arrays and objects with extra, missing,
# or reordered keys.  Repeated keys are not allowed.  Variable-length arrays are
# implemented by repeating the defined element types in a loop.  The schema may
# also contain encoded and decoded types, signifying that the corresponding
# value is a raw JSON string or a decoded JSON document.
proc ::json::unite {schema values} {
    switch [lindex $schema 0] {
    array {
        if {[llength $schema] != 2} {
            error "invalid JSON data: must be a two-element list with second\
                    element being list of array element types"
        }

        # Repeat and/or trim the subtype list to the value list length.
        set subtypes [lindex $schema 1]
        if {[llength $subtypes] < [llength $values]} {
            set subtypes [lrepeat [expr {
                ([llength $values] + [llength $subtypes] - 1)
              / [llength $subtypes]
            }] {*}$subtypes]
        }
        if {[llength $subtypes] > [llength $values]} {
            set subtypes [lreplace $subtypes [llength $values] end]
        }

        # Process each element.
        list array [lmap subtype $subtypes value $values {
            unite $subtype $value
        }]
    } object {
        if {[llength $schema] != 2} {
            error "invalid JSON object: must be a two-element list with second\
                    element being dict of object element types"
        }
        list object [dict map {key value} $values {
            if {[dict exists [lindex $schema 1] $key]} {
                unite [dict get [lindex $schema 1] $key] $value
            } elseif {[dict exists [lindex $schema 1] {}]} {
                unite [dict get [lindex $schema 1] {}] $value
            } else {
                error "key not defined in schema: $key"
            }
        }]
    } string - number - literal {
        if {[llength $schema] != 1} {
            error "invalid JSON [lindex $schema 0]: must be a one-element list"
        }
        list [lindex $schema 0] $values
    } encoded {
        if {[llength $schema] != 1} {
            error "invalid encoded JSON: must be a one-element list"
        }
        decode [lindex $values 0]
    } decoded {
        if {[llength $schema] != 2} {
            error "invalid decoded JSON: must be a two-element list"
        }
        return $values
    } default {
        error "invalid JSON type \"[lindex $schema 0]\": must be array, object,\
                string, number, literal, encoded, or decoded"
    }}
}
