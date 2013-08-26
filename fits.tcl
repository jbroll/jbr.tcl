proc fitscard { name type value { comment {} } } {

  switch [lindex $type 0] {
   i {}
   s {  set value "'$value'"				}
   r {	set value [format %f.[lindex $type 1] $value]	}
   l {  set value [expr $value ? "T" : "F"] 		}
  }

  binary format {A8A2A32A3A35} $name "= " $value " / " $comment
}

proc fits { bitpix dims bins zero data cards { ncards 0 } } {
	set fits {}

	append fits [fitscard SIMPLE %s T]
	append fits [fitscard BITPIX %d $bitpix]
	append fits [fitscard NAXIS  %d [llength $dims]]

	set d 1
	foreach dim $dims {
	    append fits [fitscard NAXIS$d %d [lindex $dims $d-1]]
	    incr d
	}
	append fits [fitscard BZERO  %f [expr $bitpix == 16 ? 32768 : 0]]
	append fits [fitscard BSCALE %f     1]

	set x    [lindex $zero 0]
	set y    [lindex $zero 1]
	set xbin [lindex $bins 0]
	set ybin [lindex $bins 1]


	set m11 [expr 1.0/[lindex $bins 0]]
	set m12 0
	set m21 0
	set m22 [expr 1.0/[lindex $bins 1]]

        append fits [fitscard LTM1_1 %f $m11]
        append fits [fitscard LTM1_2 %f $m12]
        append fits [fitscard LTM2_1 %f $m21]
        append fits [fitscard LTM2_2 %f $m22]

	append fits [fitscard LTV1  %f [expr 1.0 - (($x) + ($xbin-1)/2.0) *$m11]]
	append fits [fitscard LTV2  %f [expr 1.0 - (($y) + ($ybin-1)/2.0) *$m22]]

	append fits [fitscard HEADTIME  %.3f [expr [clock milliseconds]/1000.0]]

	foreach { name type value comment } $cards {
	    if { [catch {
		if { [string index $value 0] eq ":" } {
		    set value [set $value]
		}
	    } reply] } {
		puts $reply
		set value -1
	    }
	    append fits [fitscard $name $type $value $comment]
	}
	

        set pcards [expr max(0, ($ncards-1) - [string length $fits]/80)*80]

	append fits [binary format A$pcards { }]
        append fits [binary format A80 END]

	set padd [expr (2880-([string length $fits])%2880)%2880]
	append fits [binary format A$padd { }]


	append fits $data

	set padd [expr (2880-[string length $fits]%2880)%2880]
	append fits [binary format A$padd "\000"]

	set fits
}

proc fits-padding { size } { binary format A[expr (2880-$size%2880)%2880] "\000" }


