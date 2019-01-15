
#include <xos.h>
#include <xfile.h>
#include <msg.h>

void *radius(s, action, name, data, buff, leng)
        MsgServer        s;
        int              action;
        char            *name;
        void            *data;
        void            *buff;
        int              leng;
{
	double R = *(double *) buff;

	/* Each time the server sends a new value of R we 
	   print it out.
	 */
	printf("R = %f\n", R);
}

int init() {
	printf("Connect\n");
	return 1;

}
main()
{
        MsgServer s = msg_open("RADIUS", init, NULL);
	double R;

#if 0
	/* Set X = 2.0 and Y= 3.0.  Allow a 1 second timeout for the 
	   set to take place.
	 */
	if ( msg_setd(s, "X", 2.0, 1.0) <= 0 ) {
		printf("Error setting X: %s\n", msg_errstr);
	}
	if ( msg_setd(s, "Y", 3.0, 1.0) <= 0 ) {
		printf("Error setting Y: %s\n", msg_errstr);
	}

	/* Get the value of R explicitly and print it.
	 */
{
	int	ret;

	if ( (ret = msg_getd(s, "R", &R, 1.0)) <= 0 ) {
		printf("%d : %s\n", ret, msg_errstr);
	} else {
		printf("%d : R = %f\n", ret, R);
	}
	sleep(1);
}
#endif


	/* Subscribe to the radius and wait to see if other clients
	   change the value of X and Y.  Note that this subscription
	   will be updated by the server when clients call the setXY 
	   command but not when they set X or Y separately with "set"
	   commands.  The server could trace sets by adding function
	   callbacks to its publishcation calls of X and Y.
	 */
	msg_subscribe(s, "R", MsgDblType, &R, sizeof(double), 0.0
		, radius, NULL, 1.0);



/*
	msg_command(s, MsgNulType, NULL, 0, 1, 10.0
		, "setXY %d %d"
		, 4, 5);
 */
	msg_waitloop(&s, 1, 1, 0, 90.);

	msg_loop(s);
}

