 # ::tax::parse -- Low-level 10 lines magic parser
 #
 #        This procedure is the core of the tiny XML parser and does its
 #        job in 10 lines of "hairy" code.  The command will call the
 #        command passed as an argument for each XML tag that is found
 #        in the XML code passed as an argument.  Error checking is less
 #        than minimum!  The command will be called with the following
 #        respective arguments: name of the tag, boolean telling whether
 #        it is a closing tag or not, boolean telling whether it is a
 #        self-closing tag or not, list of property (array set-style)
 #        and body of tag, if available.
 #
 namespace eval tax {
     # Initialise the global state
     #
     variable TAX
     if {![::info exists TAX]} {
        array set TAX {
            idgene        0
        }
     }
     namespace export new parse
 }


 # ::tax::__cleanprops -- Clean parsed XML properties
 #
 #        This command cleans parsed XML properties by removing the
 #        trailing slash and replacing equals by spaces so as to produce
 #        a list that is suitable for an array set command.
 #
 proc ::tax::__cleanprops { props } {
     set name {([A-Za-z_:]|[^\x00-\x7F])([A-Za-z0-9_:.-]|[^\x00-\x7F])*}
     set attval {"[^"]*"|'[^']*'|\w}; # "... Makes emacs happy
     return [regsub -all -- "($name)\\s*=\\s*($attval)" \
                 [regsub "/$" $props ""] "\\1 \\4"]
 }

 proc tax::preparse {xml} {
     set cdata {}

     # Collect cdata in namespace variable
     # Use a non-greedy match on the body
     set re {<\!\[CDATA\[(.+?)\]\]>}
     set n 0
     while {[regexp -- $re $xml -> t] == 1} {
	 lappend cdata TAX:CDATA$n $t
	     regsub -- $re $xml "TAX:CDATA$n" xml
	     incr n
     }

     return [list $xml $cdata]
 }

 proc tax::postparse {xml} {
     set n 0
     foreach t $cdata {
	 regsub -- "TAX:CDATA$n" $xml $t xml
	 incr n
     }

     return $xml
 }
 
 proc ::tax::parse {cmd xml {start docstart}} {
      foreach { xml cdata } [preparse $xml] break

     set xml [string map { "{" "&ob;" "}" "&cb;" } $xml]

     set exp {<(/?)([^\s/>]+)\s*([^>]*)>}
     set sub "\}\n{*}$cmd {\\2} \[expr \{{\\1} ne \"\"\}\] \[regexp \{/$\} {\\3}\] \
              \[::tax::__cleanprops \{\\3\}\] \{"
     regsub -all $exp $xml $sub xml

     set xml [string map $cdata $xml]

     eval "$cmd {$start} 0 0 {} \{$xml\}"
     eval "$cmd {$start} 1 0 {} {}"
 }


 # Internal function that keeps track of the tag calling tree and
 # merges the open/close arguments into one.
 #
 proc tax::__callbacker {id cmd tag cl selfcl props bdy} {
     set varname "::tax::cx_${id}"
     upvar #0 $varname CONTEXT
 
     set tagpath $CONTEXT(lvl)
     if { $selfcl } {
        set type "OC"
     } elseif { $cl } {
        set CONTEXT(lvl) [lrange $CONTEXT(lvl) 0 end-1]
        set tagpath $CONTEXT(lvl)
        set type "C"
     } else {
        if { [string index $tag 0] ne "?" } {
            lappend CONTEXT(lvl) $tag
        }
        set type "O"
     }
 
     eval "$cmd $tag $type \{$props\} \{$bdy\} \{$tagpath\}"
 
     if { [string first "C" $type] >= 0 && [llength $CONTEXT(lvl)] == 0 } {
        unset CONTEXT
     }
 }
 
 
 # Calling this will return a command that complies to the original TAX
 # callback format and allows the command passed as an argument to
 # comply to the new argument list.
 #
 proc tax::new {cmd} {
     variable TAX
 
     set id [incr TAX(idgene)]
     set varname "::tax::cx_${id}"
     upvar \#0 $varname CONTEXT
     set CONTEXT(id) $id
     set CONTEXT(lvl) ""
 
     return "::tax::__callbacker $id $cmd"
 }

 proc tax::parser2 { cmd } {
    ::tax::parse [tax::new [list [list ::tax::xslt-proc $temp]]] $xml start
 }

 proc ::tax::xml2list { xml } {
    set xml [string map { "{" "&ob;" "}" "&cb;" } $xml]

    set xexp  {<\?([^\s/>]+)\s*([^>]*)\?>}
    set oexp  {<([^\s/>]+)\s*([^>]*)\??>}
    set cexp {</([^\s/>]+)\s*([^>]*)>}

    regsub -all {\[}  $xml \\\[ xml

    regsub      $xexp $xml { \1 { [::tax::__cleanprops {\2}] } \{}      xml
    regsub -all $oexp $xml { \1 { [::tax::__cleanprops {\2}] } \{}      xml
    regsub -all $cexp $xml \}                                           xml

    return "[subst $xml]\}"
 }
