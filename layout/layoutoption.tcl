
package require jbr::print

proc layout-option-debug { args } {
    # eprint {*}$args
}

proc layout.opt-trace { server value code } {
	layout-option-debug trace variable ::$value w CODE:$code
	trace variable ::$value w           $code
}

proc layout.option-trace { server value code } {
	layout.opt-trace $server $value $code
}

proc layout.opt-setvalue    { w option action data format name indx op } {
    upvar $name value

    try { 
        layout-option-debug set $name% [subst -nocommands {[format $format [$action $value $data]]}]
        set $name% [format $format [$action $value $data]] 
    } on error message {
        puts "setvalue $name : $message"
    }
}

proc layout.opt-setoption   { w option action data format name indx op } {
    try { 
        if { $indx eq "" } {
            upvar #0 $name value
        } else {
            upvar #0 ${name}($indx) value
        }

        $w configure $option [$action $value $data] 
    } on error message {
        puts "setoption $name : $message"
    }
}

proc layout.opt-bind { w option server value format default} {
    layout-option-debug bind $w $option server: $server value: $value format: $format default: $default"

    set action layout.opt-echo
    set data   {}
    switch -glob $value {
        *@* { set action layout.opt-indx;  foreach { value data } [split $value @] break }
        *#* { set action layout.opt-hash;  foreach { value data } [split $value #] break }
        *&* { set action layout.opt-buck;  foreach { value data } [split $value &] break }
        *!* { set action layout.opt-xxec;  foreach { value data } [split $value !] break }
    }

    if { $format eq "" } { set format %s }

    if { 0 && $default eq "" } {
        layout.option-trace $server $value [list layout.opt-setvalue  $w $option $action $data $format]
        set value $value%
    } else {
        layout.option-trace $server $value [list layout.opt-setoption $w $option $action $data $format]
        if { $default eq "" } {
            upvar ::$value v
            set value [$action $v $data]
        } else {
            set value $default
        }
    }

    return $value
}

proc layout.opt-echo { value data } { return $value }
proc layout.opt-indx { value data } { return [lindex [set ::${data}] $value] }
proc layout.opt-xxec { value data } { return [{*}${data} $value] }
proc layout.opt-hash { value data } { 
    try { set reply [set ::${data}($value)] 
    } on error message {
        try { set reply [set ::${data}(default)]
        } on error message { puts "cannot lookup $value or default in $data" }
    }

    return $reply
}
proc layout.opt-buck { value data } {
    lindex [lindex [set ::${data}] 1] [lsearch -bisect -real [lindex [set ::${data}] 0] $value]
}

proc layout.opt-vformat { format name args } {
    catch { set $name% [format $format [set ::$name]] }
}

proc layout.options { comm item w options } {
    set reply {}

    foreach { option value } $options {
        if {[regexp {^(?:([^:, ]+):)?[:]([^,% ]+)(?:%([^, ]+))?(?:,(.+))?$} $value _ server name format default]} {

            set value [layout.opt-bind $w $option $server $name $format $default]
        }
        lappend reply $option $value
    }

    return $reply
}
