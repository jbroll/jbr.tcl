# Declair accessor methods for instance variables
#
proc oo::define::accessor args {
    set currentclass [lindex [info level 1] 1]

    foreach var $args {
	oo::define $currentclass [subst { method $var args { set $var {*}\$args } }]
    }
}
    #oo::class create X {
    #    variable a b c
    #    accessor a b 
    #
    #    constructor {} {
    #	     set a 34
    #    }
    #}
    #
    #X create x
    #puts [x a]
    #x a 21
    #puts [x a]


# Control method visibility
# 
proc oo::define::public { method name args body } {
      uplevel 1 [list method $name $args $body]
      uplevel 1 [list export $name]
}
proc oo::define::private { method name args body } {
      uplevel 1 [list method $name $args $body]
      uplevel 1 [list unexport $name]
}

	#oo::class create X {
	#    public method XXX {} { puts XXX }
	#}
	#	
	#X create a
	#a XXX
	#	
	#exit

# Create procs in the objects namespace that forward calls to class methods.  This
# allows methods to be called without [self] or [my].
#
proc procs args {
    foreach proc $args {
	proc [uplevel 1 { namespace current }]::$proc args [subst { tailcall my $proc {*}\$args }]
    }
}
    #oo::class create X {
    #    constructor {} {
    #	nsproc a b c 
    #    }
    #
    #    method a {} { b }
    #    method b {} { puts XXX }
    #}
    #
    #X create x
    #x a


