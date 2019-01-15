
#include <xos.h>
#include <xfile.h>
#include <msg.h>

int   amp1;	
char  amp1dat[(4096+512) * 2048];


void *syncdata(m, op, name, data, buff, leng) 
	MsgServer m;
	int       op;
	char	 *name;
	char     *data;
	char	 *buff;
	int	  leng;

{
    switch ( op ) {
	case MsgSetVal:
    	    fprintf(stdout, "Data arrives at %d leng: %d\n"
		    	, buff - data, leng);
	    break;
    }
}

main(argc, argv)
	int	 argc;
	char	*argv[];
{
    MsgServer	m;
	
    if ( !(m = msg_open("MSERV", NULL, NULL)) ) {
	fprintf(stderr, "Cannot open server?\n");
	exit(1);
    }

    if ( !msg_subscribe(m, "AMP01", MsgBusType, amp1dat, 64000
	    	, 0.0, syncdata, amp1dat, 4.0) ) {
	fprintf(stderr, "Cannot make subscription.\n");
	exit(1);
    }
    if ( !msg_subscribe(m, "AMP32", MsgBusType, amp1dat, 64000
	    	, 0.0, syncdata, amp1dat, 4.0) ) {
	fprintf(stderr, "Cannot make subscription.\n");
	exit(1);
    }
    if ( !msg_subscribe(m, "AMP72", MsgBusType, amp1dat, 64000
	    	, 0.0, syncdata, amp1dat, 4.0) ) {
	fprintf(stderr, "Cannot make subscription.\n");
	exit(1);
    }
    msg_loop(m);
}

