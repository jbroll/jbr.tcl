#!/usr/bin/env tclkit8.6.1
#

 oo::class create __linked {
    constructor { args } {
	# Don't know if the class has a constructor, catch a bad call
	#
	catch { next {*}$args }

	# Create the links
	#
	foreach link [set [[info object class [self]] varname __linked]] {
	    proc [namespace current]::$link args [subst { tailcall my $link {*}\$args }]
	}
    }
 }
 oo::class create _linked {
    variable __linked

    constructor { args } {
	set __linked {}

	next {*}$args

	oo::define [self] { mixin -append __linked }
    }
 }
 oo::define oo::class {
    mixin -append _linked
 }

 proc oo::define::linked { args } {
    set class [lindex [info level -1] 1]
    oo::define $class { self export varname }

    if { [lindex $args 0] ne "method" } {
	set method [lindex $args 2]		; # Skip over public / private
    } else {
	set method [lindex $args 1]
    }

    lappend [$class varname __linked] $method	; # remember linked methods

    uplevel 1 $args
 }

 oo::class create foo {
    linked method method2 { y } { puts $y }

    method method1 { y } {
	method2 $y
    }
 }

 foo create inst
 inst method1 1
