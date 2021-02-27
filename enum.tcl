
::oo::class create enum {
    constructor { to_sym } {
        my variable toSym ;    set toSym $to_sym
        my variable toVal ;    set toVal [zip [dict values $to_sym] [dict keys $to_sym]]
    }

    method toSym { value } {
        variable toSym
        dict get@ $toSym $value $value
    }
    method toVal { symbol } {
        variable toVal
        dict get@ $toVal $symbol $symbol
    }
}
