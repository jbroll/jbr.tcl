#!/bin/ksh
#
HOST=192.168.2.5
HOST=shadow
MULT=239.137.12.3
PORT=5413
AMPS=1000
NAMP=4

	echo setenv MSERV *:$PORT
        echo ""

for n in $(nawk "BEGIN { for ( i = 1; i <= $NAMP; i++ ) { print i } }") ; do
    amp=`printf %02d $n`
    echo setenv megaamp$amp $MULT:$AMPS$amp
done

