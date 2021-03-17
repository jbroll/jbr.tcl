 # This code is an operator precedence parser which uses an operator table and a variation 
 # on the shunting yard parser algorithm to convert an infix expression to a series of 
 # prefix operator callbacks.
 #
 #
 namespace eval expression {
    # This is the operator precedence table for C++.  The dot operator is effectively
    # commented out by "renaming" it ".###".  The lexical "analyser" is too primitive 
    # to distinguish floating point numbers and a real . operator usage.
    #
    # The conditional, "?:" and sequence operator, "," are missing.
    #
    # precedence values are spaced out by multiplying the nominal
    # C++ precedence by 10.  This should allow applications to add other
    # operators as needed at any preceduce (???) required.
    #
    # The unary * has been changes to nulary to support tna
    #
    # The index [] operator is nary and treated similarly to a function call to "indx" instead
    # of "call".
    #
    # dolar "$" is added for eventual support of tcl variables in tna.
    #
    variable optable {
        ::        {   10                 2        left        name   }
        ++        {   20                 1        left        inc    }
        --        {   20                 1        left        dec    }
      .###        {   20                 2        left        dot    }
        ->        {   20                 2        left        arrow  }
       ++u        {   30                 1        right       uinc   }
       --u        {   30                 1        right       udec   }
        -u        {   30                 1        right       usub   }
        +u        {   30                 1        right       uadd   }
        *u        {   30                 0        right       deref  }
        $u        {   30                 1        right       dolar  }
        &u        {   30                 1        right       refer  }
         *        {   50                 2        left        mul    }
         /        {   50                 2        left        div    }
         %        {   50                 2        left        mod    }
         +        {   60                 2        left        add    }
         -        {   60                 2        left        sub    }
        <<        {   70                 2        left        shl    }
        >>        {   70                 2        left        shr    }
         >        {   80                 2        left        gt     }
         <        {   80                 2        left        lt     }
        <=        {   80                 2        left        lte    }
        >=        {   80                 2        left        gte    }
        ==        {   90                 2        left        equ    }
        !=        {   90                 2        left        neq    }
         &        {  100                 2        left        band   }
         ^        {  110                 2        left        bxor   }
         |        {  120                 2        left        bor    }
        &&        {  130                 2        left        land   }
        ||        {  140                 2        left        lor    }
         ?        {  150                 2        right       hook   }
         =        {  160                 2        right       assign }
        +=        {  160                 2        right       addasn }
        -=        {  160                 2        right       subasn }
        *=        {  160                 2        right       mulasn }
        /=        {  160                 2        right       divasn }
        %=        {  160                 2        right       modasn }
       <<=        {  160                 2        right       shlasn }
       >>=        {  160                 2        right       shrasn }
        &=        {  160                 2        right       bndasn }
        ^=        {  160                 2        right       bxrasn }
        |=        {  160                 2        right       borasn }
         [        { 1000                 0        {}          indx   }
         ]        { 1000                 0        {}          none   }
         (        { 1000                 0        {}          call   }
         )        { 1000                 0        {}          none   }
         ,        { 1000                 0        {}          none   }
         ;        { 1000                 0        {}          semi   }
    }


    # A little helper to sort a precedence table in to a [string map] mapping that will be used
    # for "lexical analysis".
    #
    proc prep-tokens { tokens } {
        variable opers

        foreach token [dict keys $tokens] {
            set opers([lindex [dict get $tokens $token] 3]) $token

            set token [string map { u {} } $token]
            lappend map $token " $token "
        }
        lappend map "\n" " ; "
        lsort -stride 2 -command lencmp [lsort -stride 2 -u $map]
    }

        proc lencmp { a b } {
            return [expr [string len $b] - [string len $a]]
        }

    # Accessors for the operator table data structure.
    #
    proc prec { tok } {                        # Return the precedence of an operator.
        upvar optable optable

        set reply 0
        catch { set reply [lindex [dict get $optable $tok] 0] }
        return $reply
    }
    proc arity { tok } {                # Return the arity of an operator.
        upvar optable optable

        set reply 0
        catch { set reply [lindex [dict get $optable $tok] 1] }
        return $reply
    }
    proc assoc { tok } {                # Return the assiciativity of an operator.
        upvar optable optable

        set reply 0
        catch { set reply [lindex [dict get $optable $tok] 2] }
        return $reply
    }
    proc name { tok } {                        # Return the name of an operator.
        upvar optable optable

        set reply 0
        catch { set reply [lindex [dict get $optable $tok] 3] } reply; # puts $reply
        return $reply
    }

    # Stack operators.
    #
    proc push { stkName value }   { upvar $stkName stk;   lappend stk $value }
    proc pop  { stkName { n 1 } } { upvar $stkName stk;
        set x [expr $n-1]
        set top [lrange $stk end-$x end]
        set stk [lrange $stk      0 end-$n]
        if { $n == 1 } {
            return [join $top]
        } else {
            return $top
        }
    }
    proc top  { stkName }         { upvar $stkName stk;   return [lindex $stk end] }
    proc pull { stkName }         { upvar $stkName stk;   set stk [lassign $stk top]; return $top }
    proc next { stkName }         { upvar $stkName stk;   return [lindex $stk 0] }

    # Here is the parser.  You pass in the input string, the token map, the operator precedence table and
    # a script prefix with will be called as each sub-expression in the input is recognized.
    #
    proc parse { input tokenmap optable prefix } {
        set operator {}                                        ; # Stacks
        set operands {}
        set parens   {}
        set prv {}                                        ; # The previous token.

        set input [string map $tokenmap $input]                ; # Lexing done by mapping spaces around the operators!

        #puts $input

        {*}$prefix initialize

        set result {}
        try {
            while { [llength $input] } {
                set tok [pull input]

                if { $tok eq ";" } {
                    while { [top operator] ne {} } {
                        push operands [{*}$prefix [name [set op [pop operator]]] {*}[pop operands [arity $op]]]
                    }
                    lappend result [{*}$prefix [name ";"] [pop operands]]

                    # Reset everyone
                    #
                    set operator {}                        ; # Stacks
                    set operands {}
                    set parens   {}
                    set prv {}                                ; # The previous token.

                    continue
                }

                if { [prec ${tok}u] && $prv ne ")" && ($prv eq {} || [prec $prv]) } {
                    set tok ${tok}u
                }

                #puts "$tok [prec $tok], op: $operator args: $operands"


                if { ![prec $tok] } {                                                        ; # Push operand
                    if { $prv ne {} && ![prec $prv] } { error "unexpected token : $prv _@_ $tok" }

                    push operands $tok
                } elseif {  $tok eq "("
                        ||  $tok eq {[}
                        ||  [top operator] eq {}
                        ||  [prec $tok] <  [prec [top operator]]
                        || ([prec $tok] <= [prec [top operator]]
                         && [assoc $tok] eq "right" ) } {

                    if { $tok eq "(" || $tok eq {[} } {
                        if { $tok eq {[} || ($prv ne {} && ![prec $prv]) } {
                            if { [next input] eq ")" }        { push parens 0                ; # Function call or Index
                            } else                         { push parens 1   }
                        } else                                 { push parens "(" }        ; # Normal expression paren
                    } else {
                        if { [prec ${tok}u] && ($prv eq {} || $prv eq "," || $prv eq "(" || $prv eq {[}) } {
                            set tok ${tok}u
                        }
                    }

                    push operator $tok

                } elseif { $tok eq ")" || $tok eq {]} || $tok eq "," } {        ; # Function call, Index or comma
                    switch [top parens] {
                     {}  { error "unexpected \")\" : $prv $tok [next input]"        }

                     "(" {                                                        ; # Close paren on normal expression paren
                        while { [top operator] ne "(" } {
                            push operands [{*}$prefix [name [set op [pop operator]]] {*}[pop operands [arity $op]]]
                        }
                        pop operator
                        pop parens
                     }
                     default {                                                                ; # Function call, Index or comma
                        if { $tok eq "," } { push parens [expr [pop parens]+1] }        ; # Incr function nargs

                        while { [top operator] ne "(" && [top operator] ne {[} } {        ; # Output function arg
                            push operands [{*}$prefix [name [set op [pop operator]]] {*}[pop operands [arity $op]]]
                        }
                        if { $tok eq ")" || $tok eq "]" } {                                ; # Output function call or Index
                            push operands [{*}$prefix [name [pop operator]] {*}[pop operands [expr [pop parens]+1]]]
                        }
                     }
                    }
                } else {
                    while { [top operator] ne {} && [prec $tok] >= [prec [top operator]] } {
                        push operands [{*}$prefix [name [set op [pop operator]]] {*}[pop operands [arity $op]]]
                    }
                    push operator $tok
                }

                set prv $tok

            }
            if { $parens ne {} } { error "parens not balanced" }

            while { [top operator] ne {} } {
                push operands [{*}$prefix [name [set op [pop operator]]] {*}[pop operands [arity $op]]]
            }
        } on error message {
            puts $::errorInfo
            error "parse error at: $prv _@_ $tok [next input] : $message"
        
        }

        lappend result [{*}$prefix [name ";"] [pop operands]]
        return $result
    }
 }
