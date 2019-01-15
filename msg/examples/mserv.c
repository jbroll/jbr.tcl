
#include <xos.h>
#include <xfile.h>
#include <msg.h>

#define NAMPS		1
#define ROWS		(4096+512)
#define COLS		2048
#define RowsPerChunk	24

#ifdef TEST
#define NAMPS		1
#define ROWS		100
#define COLS		100
#define RowsPerChunk	50
#endif

int   amp[NAMPS];	

char  ampdat[ROWS * COLS];


double postdata(m, tid, state) 
	MsgServer m;
	int	  tid;
	int      *state;
{
    int	a, i;

    switch ( *state ) {
	case 0:

	    fprintf(stderr, "post %d\n", *state);


	    for ( i = 0; i < ROWS/RowsPerChunk; i++ ) {
		for ( a = 0; a < NAMPS; a++ ) {
		    msg_buspost(m, amp[a], ampdat, COLS*RowsPerChunk*i, COLS*RowsPerChunk);
SAOusleep(0.1);
		    msg_bussync(m, amp[a]);
		}
	    }
	    (*state)++;
	    break;
	case 1:
	    *state = 0;
	    break;
	    fprintf(stderr, "sync\n");
	    for ( a = 0; a < NAMPS; a++ ) {
		msg_bussync(m, amp[a]);
	    }
	    break;
    }

    return 1.0;
}

main(argc, argv)
    int	 argc;
    char	*argv[];
{
    int 	a, state = 0;
    MsgServer	m;

    if ( (m = msg_server(argv[0])) == NULL ) {
	perror("mserv");
	exit(1);
    }

    for ( a = 0; a < NAMPS; a++ ) {
	if ( !(amp[a] = msg_publish(m, "AMP%02d", MsgBusType
			, ampdat, sizeof(ampdat)
			, NULL, NULL, NULL, a+1)) ) {
	    fprintf(stderr, "Cannot publish megaamp%02d\n", a+1);
	    exit(1);
	}
    }

    msg_addtimer(m, 1.0, postdata, &state);
    msg_up(m, argv[0]);
    msg_loop(m);
}

