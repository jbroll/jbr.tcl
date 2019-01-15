#include <xos.h>
#include <xfile.h>
#include <msg.h>

/* These are the server published variables and kept as global in this
   example.  They don't need to be.  The address of a server control struct
   could be passed around in the callback closure data.
 */
int	mode, prev_mode;
double	X, Y, R;

double sqrt();

void init_mode(m) {
	printf("Mode: %d\n", mode);
}

void *setmode(s, action, name, data, buff, leng)
        MsgServer        s;
        int              action;
        char            *name;
        void            *data;
        void            *buff;
        int              leng;
{
	static prev_mode;

    if ( action == MsgSetVal ) {
	switch ( mode ) {
	  /* Set the server to operate in the new mode
	   */
	  case 0:	init_mode(mode);	break;
	  case 1:	init_mode(mode);	break;
	  case 2:	init_mode(mode);	break;

	  /* Force and error on invalid mode values
	   */
	  default:
		mode = prev_mode;
		return NULL;
	}

	prev_mode = mode;
	return buff;
    } else {

	/* It always ok for a client to read the current mode value.
	   If NULL were returned here it would impliment a write-only
	   published value.
	 */
	return buff;
    }
}

void *setR(s, action, name, data, buff, leng)
        MsgServer        s;
        int              action;
        char            *name;
        void            *data;
        void            *buff;
        int              leng;
{
    if ( action == MsgSetVal )	return NULL;	/* Returning NULL makes R read only */
    else {
	/* Compute R is someone tries to get it
	 */
	R = sqrt(X*X + Y*Y);

	return buff;
    }
}


double postR(s, tid, data)
	int	tid;
	void	*data;
{
	double r = sqrt(X*X + Y*Y);
	X++;

fprintf(stderr, "Post R\n");
	/* Send out the value of R to all interested clients.
	 */
	msg_postval(s, "R", &r);

	return 1.0;
}

void setXY(s, c, msgid, data, argc, argv)
        MsgServer        s;
        Client           c;
        int              msgid;
        char            *data;
        int              argc;
        char            *argv[];
{
	    double r;

	if ( argc != 3 ) {
	    msg_nak(c, msgid, "setxy: incorrect number of args");
	    return;
	}

	X = atof(argv[1]);
	Y = atof(argv[2]);

	r = sqrt(X*X + Y*Y);	/* New R */

	/* Call post immedietly on computing the new value of R
	 */
	sleep(2);
	msg_postval(s, "R", &r);
	msg_ack(c, msgid, NULL);
}

main()
{
        MsgServer s;

	char *str = "cool";

	/* Initialize the server mode
	 */
	mode = 0;
	prev_mode = 0;

        if ( (s = msg_server("EX")) == NULL ) {
	    fprintf(stderr, "radius: can't open server end\n");
	    exit(1);
	};
 
	/* Two variables that are managed completely by the msg library.
	   they are set by "set" commands and read with "get" commands 
	   from clients.
	 */
	msg_publish(s, "X", MsgDblType, &X, 0, NULL, NULL
		, "-sub 1 -default 1 -- Server variable X");
	msg_publish(s, "Y", MsgDblType, &Y, 0, NULL, NULL
		, "-sub 5 -default 1 -- Server variable Y");

	msg_publish(s, "K", MsgStrType, str, 4, NULL, NULL, NULL);

	/* The mode is manipulated as a published variable, but the server
	   gets a callback when a client tries to get or set it.

	   The setmode callback can take actions and enforce valid mode 
	   values.
	 */
	msg_publish(s, "Mode", MsgIntType, &mode, sizeof(int), setmode, NULL
		, "-- Server mode");


	/* This is the Radius, a published value that is meant for clients
	   to subscribe to.
	 */
	msg_publish(s, "R", MsgDblType, &R, sizeof(double), setR, NULL
		, "-init Server -mode ro -sub 0 -- Radius");

	/* Post the value of R to all interested clients every second.
	 */
	msg_addtimer(s, 1.0, postR, NULL);


	/* Create a command to provide an alternate interface to setting
	   X and Y via set commands.  Here new X, Y values are args to the 
	   setXY command and are set at the same time.
	 */
	msg_register(s, "setXY", 0, setXY, NULL, "-name X -name Y -- set server xy");

	/* Run the server
	 */
	msg_loop(s);	/* Doesn't return */
}
