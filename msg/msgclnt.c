/* msgclnt.c

 Public client side functions.

 */

#include <xos.h>
#include <xfile.h>
#include "msg.h"


/* #msg_open makes a connection to a server.
 */

MsgServer msg_client(server, state, sdata, tag)
	char	*server;		/* Server name.		*/
	int	(*state)();		/* State callback	*/
	void	*sdata;			/* Closure data for state callback */
	char	*tag;
{
	MsgServer s;
	char	*sok;

    if ( !strcmp(server, "dev:NULL") ) { return NULL; }

    New(s, struct MsgServer);

    if (  (sok = getenv(server)) == NULL ) {
            return NULL;
    }
    msg_debug = getenv("MSGDEBUG") != 0;

    msg_register(s, "set", MsgNArgs | 3  , imsg_set, NULL, "Set a value that client has subscribed to");
    msg_register(s, "blk", MsgNoParseArgs, imsg_ack, NULL, "Set a binary data block");
    msg_register(s, "ack", MsgNoParseArgs, imsg_ack, NULL, "Acknowledge a successful set or blk command");
    msg_register(s, "nak", MsgNoParseArgs, imsg_nak, NULL, "Acknowledge an error on a set or blk command");

    s->clnts[0].server= s;
    s->clnts[0].type  = MsgClientSide;
    s->clnts[0].tag   = strdup(tag);

    s->name  = strdup(server);
    s->sok   = strdup(sok);

    s->newclient = NULL;
    s->kilclient = NULL;
    s->error     = NULL;
    s->logfile   = NULL;

    s->state = state;
    s->sdata = sdata;
    s->msgid = 1;

    msg_loginit(s, NULL);

    msg_reopen(s);

    return s;
}
MsgServer msg_open(server, state, sdata)
	char	*server;		/* Server name.		*/
	int	(*state)();		/* State callback	*/
	void	*sdata;			/* Closure data for state callback */
{
	return msg_client(server, state, sdata, "-");
}

#ifdef __STDC__
/* #msg_subscribegroup subscribes to a variable on the server.  Each time the serve
r
   posts a new value for the subscribed variable the client callback will be
   called.
 */
int msg_subscribegroup(
        MsgServer        s,             /* Server handle        */
        char            *name,          /* Variable name        */
        int              type,          /* Data type            */
        void            *buff,          /* Pointer to vairable data buffer */
        int              leng,          /* Length of data buffer        */
        int              Group,         /* async group name */
        double           timer,         /* Periodic update of value     */
        MsgValueFunc     func,          /* Callback function            */
        void            *data,          /* Closure data for callback    */
        double           timeout,       /* Subscription command timeout */
        ...)
{
    int ret;
    va_list         args;
    va_start(args, timeout);
#else
int msg_subscribegroup(va_alist) va_dcl
{
    va_list         args;

        MsgServer        s;             /* Server handle        */
        char            *name;          /* Variable name        */
        int              type;          /* Data type            */
        void            *buff;          /* Pointer to vairable data buffer */
        int              leng;          /* Length of data buffer        */
        int              Group,         /* async group name */
        double           timer;         /* Periodic update of value     */
        MsgValueFunc     func;          /* Callback function            */
        void            *data;          /* Closure data for callback    */
        double           timeout;       /* Subscription command timeout */
        int     ret;

    va_start(args);

        s       = va_arg(args, MsgServer);
        name    = va_arg(args, char *);
        type    = va_arg(args, int);
        *buff   = va_arg(args, void *);
        leng    = va_arg(args, int);
        Group   = va_arg(args, int);
        timer   = va_arg(args, double);
        func    = va_arg(args, MsgValueFunc);
        data    = va_arg(args, void *);
        timeout = va_arg(args, double);
#endif

   {
        char    formatted[256];
        int     nth;

    vsprintf(formatted, name, args);
    nth = MsgAddValue(s, formatted, type, buff, leng, func, data, NULL, timer)
;

    if ( s->up ) {
        if ( type == MsgBlkType )
            ret = msg_quemsg(s, &s->clnts[0]
                            , MsgNulType, NULL, 0
                            , Group, timeout, "sub %s %g %d\n", formatted, timer, leng);
         else
            ret = msg_quemsg(s, &s->clnts[0]
                            , MsgNulType, NULL, 0
                            , Group, timeout, "sub %s %g\n", formatted, timer);
    }

    if ( type == MsgBusType ) {
        if ( !MsgCastSubscribe(s, nth) ) return 0;
    }

    return 1;
  }
}



#ifdef __STDC__
/* #msg_subscribe subscribes to a variable on the server.  Each time the server
   posts a new value for the subscribed variable the client callback will be
   called.
 */
int msg_subscribe(
	MsgServer	 s,		/* Server handle	*/
	char		*name,		/* Variable name	*/
	int		 type,		/* Data type		*/
	void		*buff,		/* Pointer to vairable data buffer */
	int		 leng,		/* Length of data buffer	*/
	double		 timer,		/* Periodic update of value	*/
	MsgValueFunc	 func,		/* Callback function		*/
	void	 	*data,		/* Closure data for callback	*/
	double		 timeout,	/* Subscription command timeout	*/
	...)
{
    va_list         args;
    va_start(args, timeout);
#else
int msg_subscribe(va_alist) va_dcl
{
    va_list         args;

	MsgServer	 s;		/* Server handle	*/
	char		*name;		/* Variable name	*/
	int		 type;		/* Data type		*/
	void		*buff;		/* Pointer to vairable data buffer */
	int		 leng;		/* Length of data buffer	*/
	double		 timer;		/* Periodic update of value	*/
	MsgValueFunc	 func;		/* Callback function		*/
	void	 	*data;		/* Closure data for callback	*/
	double		 timeout;	/* Subscription command timeout	*/

    va_start(args);

	s	= va_arg(args, MsgServer);
	name	= va_arg(args, char *);		
	type	= va_arg(args, int);		
	*buff	= va_arg(args, void *);		
	leng	= va_arg(args, int);		
	timer	= va_arg(args, double);		
	func	= va_arg(args, MsgValueFunc);	
	data	= va_arg(args, void *);
	timeout = va_arg(args, double);	
#endif

	int	ret = 0;

   {
	char	formatted[256];
	int	nth;

    vsprintf(formatted, name, args);
    nth = MsgAddValue(s, formatted, type, buff, leng, func, data, NULL, timer);

    if ( s->up ) {
	if ( type == MsgBlkType )
	    ret = msg_quemsg(s, &s->clnts[0]
			    , MsgNulType, NULL, 0
			    , MsgWait, timeout, "sub %s %g %d\n", formatted, timer, leng);
	 else 
	    ret = msg_quemsg(s, &s->clnts[0]
			    , MsgNulType, NULL, 0
			    , MsgWait, timeout, "sub %s %g\n", formatted, timer);
    }

    if ( ret < 0 ) return 0;

    if ( type == MsgBusType ) {
	if ( !MsgCastSubscribe(s, nth) ) return 0;
    }

    return 1;
  }
}


/* #msg_unsubscribe removes a client from the subscription list for the
   variable.
 */
int msg_unsubscribe(s, name, timeout)
	MsgServer	 s;
	char		*name;
{
	MsgValue   value;
	int	msgid;

    if ( (value = msg_lookupval(s, name)) == NULL ) {
	return 0;
    }

    return msg_quemsg(s, &s->clnts[0]
			, MsgNulType, NULL, 0
			, MsgWait, timeout, "uns %s", name);
}


/* #msg_list lists all of the commands and published variables available of 
   a server.
 */

msg_list(s)
	MsgServer	 s;
{
	msg_print(s->clnts[0].out, "1 lst\n");
}


/* #msg_command sends a formatted ascii command to the server.
 */
#ifdef __STDC__
msg_clntcmd(
	  MsgServer s
        , int c
	, int type
	, void *data
	, int leng
	, int group
	, double timeout
	, char *command, ...)
{
        va_list         args;
	char	  cmd[1024];
	int	  i;

    va_start(args, command);
#else
msg_clntcmd(va_alist) va_dcl
{
    va_list         args;
 
	MsgServer s;
        int c;
	int type;
	void *data;
	int leng;
	int group;
	double timeout;
	char *command;

	char	  cmd[1024];
	int	  i;

    va_start(args);
        s     	= va_arg(args, MsgServer);
        c	= va_arg(args, int);
	type	= va_arg(args, int);
	data	= va_arg(args, void *);
	leng	= va_arg(args, int);
	group	= va_arg(args, int);
	timeout	= va_arg(args, double);
	command	= va_arg(args, char *);
#endif

    vsprintf(cmd, command, args);

    if ( c >  0 ) {
        return msg_quemsg(s, &s->clnts[c], type, data, leng, group
		, timeout, cmd);
    }

    if ( c == 0 ) {
	for ( i = 0; i < MsgMaxClients; i++ ) {
            if ( s->clnts[i].inp != NULL ) {
		msg_quemsg(s, &s->clnts[i], type, data, leng, group
			, timeout, cmd);
	    }
	}
    }

    if ( c <  0 ) {
	c = (-c) - 1;

	for ( i = 0; i <  s->values[c].nsubs; i++ ) {
            if ( s->values[c].subs[i].client != NULL ) {
		msg_quemsg(s, s->values[c].subs[i].client
			, type, data, leng, group, timeout, cmd);
	    }
	}
    }
}


/* #msg_command sends a formatted ascii command to the server.
 */
#ifdef __STDC__
msg_command(
	  MsgServer s
	, int type
	, void *data
	, int leng
	, int group
	, double timeout
	, char *command, ...)
{
        va_list         args;

	Client	  c;
	char	  cmd[1024];

    va_start(args, command);
#else
msg_command(va_alist) va_dcl
{
    va_list         args;
 
	MsgServer s;
	int type;
	void *data;
	int leng;
	int group;
	double timeout;
	char *command;

	Client	  c;
	char	  cmd[1024];


    va_start(args);
        s     	= va_arg(args, MsgServer);
	type	= va_arg(args, int);
	data	= va_arg(args, void *);
	leng	= va_arg(args, int);
	group	= va_arg(args, int);
	timeout	= va_arg(args, double);
	command	= va_arg(args, char *);
#endif

    c = &s->clnts[0];

    vsprintf(cmd, command, args);
    return msg_quemsg(s, c, type, data, leng, group, timeout, cmd);
}


/* Get an integer value for the server.  Don't wait for the reply.
 */
int msg_ageti(s, name, group, valptr, timeout)
        MsgServer        s; 
        char            *name;
        int              group;
	int		*valptr;
	double		 timeout;
{
    return msg_quemsg(s, &s->clnts[0]
			, MsgIntType, valptr, sizeof(int)
			, group, timeout, "get %s", name);
}

/* Get an float value for the server.  Don't wait for the reply.
 */
int msg_agetf(s, name, group, valptr, timeout)
        MsgServer        s; 
        char            *name;
        int              group;
	float		*valptr;
	double		 timeout;
{
    return msg_quemsg(s, &s->clnts[0]
			, MsgFltType, valptr, sizeof(float)
			, group, timeout, "get %s", name);
}

/* Get an double value for the server.  Don't wait for the reply.
 */
int msg_agetd(s, name, group, valptr, timeout)
        MsgServer        s; 
        char            *name;
        int              group;
	double		*valptr;
	double		 timeout;
{
	return msg_quemsg(s, &s->clnts[0]
			, MsgDblType, valptr, sizeof(double)
			, group, timeout, "get %s", name);
}

/* Get an string value for the server.  Don't wait for the reply.
 */
int msg_agetstr(s, name, group, valptr, max, timeout)
        MsgServer        s; 
        char            *name;
        int              group;
	char		*valptr;
	int		 max;
	double		 timeout;
{
    return msg_quemsg(s, &s->clnts[0]
			, MsgStrType, valptr, max
			, group, timeout, "get %s", name);
}

/* Get an data block for the server.  Don't wait for the reply.
 */
int msg_agetblk(s, name, group, valptr, leng, timeout)
        MsgServer        s; 
        char            *name;
        int              group;
	void		*valptr;
	int		 leng;
	double		 timeout;
{
    return msg_quemsg(s, &s->clnts[0]
			, MsgBlkType, valptr, leng
			, group, timeout, "get %s %d", name, leng);
}

/* #msg_seti sets a server variable from an integer and waits for an
   acknowedgement from the server.
 */
int msg_seti(s, name, val, timeout)
        MsgServer        s; 
        char            *name;
	int		 val;
	double		 timeout;
{
	return msg_aseti(s, name, MsgWait, val, timeout);
}


/* #msg_setf sets a server variable from a float and waits for an
   acknowedgement from the server.
 */
int msg_setf(s, name, val, timeout)
        MsgServer        s; 
        char            *name;
	double		 val;
	double		 timeout;
{
	return msg_asetf(s, name, MsgWait, val, timeout);
}

/* #msg_setd sets a server variable from a double and waits for an
   acknowedgement from the server.
 */
int msg_setd(s, name, val, timeout)
        MsgServer        s; 
        char            *name;
	double		 val;
	double		 timeout;
{
	return msg_asetd(s, name, MsgWait, val, timeout);
}


/* #msg_setstr sets a server variable from a string and waits for an
   acknowedgement from the server.
 */
int msg_setstr(s, name, val, timeout)
        MsgServer        s; 
        char            *name;
	char		*val;
	double		 timeout;
{
	return msg_asetstr(s, name, MsgWait, val, timeout);
}

/* #msg_setblk sets a server variable from a binary data block and waits for an
   acknowedgement from the server.
 */
int msg_setblk(s, name, val, leng, timeout)
        MsgServer        s; 
        char            *name;
	void		*val;
	double		 timeout;
{
	return msg_asetblk(s, name, MsgWait, val, leng, timeout);
}


/* #msg_asetd sets a server variable from an integer without waiting for an
   acknowedgement from the server.
 */
int msg_aseti(s, name, group, val, timeout)
        MsgServer        s; 
        char            *name;
	int		 group;
	int		 val;
	double		 timeout;
{
	return msg_xseti(s, &s->clnts[0], name, group, val, timeout);
}

/* #msg_asetd sets a server variable from a float without waiting for an
   acknowedgement from the server.
 */
int msg_asetf(s, name, group, val, timeout)
        MsgServer        s; 
        char            *name;
	int		 group;
	double		 val;
	double		 timeout;
{
	return msg_xsetf(s, &s->clnts[0], name, group, val, timeout);
}

/* #msg_asetd sets a server variable from a double without waiting for an
   acknowedgement from the server.
 */
int msg_asetd(s, name, group, val, timeout)
        MsgServer        s; 
        char            *name;
	int		 group;
	double		 val;
	double		 timeout;
{
	return msg_xsetd(s, &s->clnts[0], name, group, val, timeout);
}

/* #msg_asetstr sets a server variable from a string without waiting for an
   acknowedgement from the server.
 */
int msg_asetstr(s, name, group, val, timeout)
        MsgServer        s; 
        char            *name;
	int		 group;
	char		*val;
	double		 timeout;
{
	return msg_xsetstr(s, &s->clnts[0], name, group, val, timeout);
}

/* #msg_asetblk sets a server variable from a binary data block without waiting for an
   acknowedgement from the server.
 */
int msg_asetblk(s, name, group, val, leng, timeout)
        MsgServer        s; 
        char            *name;
	int		 group;
	void		*val;
	double		 timeout;
{
	return msg_xsetblk(s, &s->clnts[0], name, group, val, leng, timeout);
}

/* Get an integer value for the server.  Wait for the reply.
 */
int msg_geti(s, name, valptr, timeout)
        MsgServer        s; 
        char            *name;
	int		*valptr;
	double		 timeout;
{
	return msg_ageti(s, name, MsgWait, valptr, timeout);
}

/* Get an float value for the server.  Wait for the reply.
 */
int msg_getf(s, name, valptr, timeout)
        MsgServer        s; 
        char            *name;
	float		*valptr;
	double		 timeout;
{
	return msg_agetf(s, name, MsgWait, valptr, timeout);
}

/* Get an double value for the server.  Wait for the reply.
 */
int msg_getd(s, name, valptr, timeout)
        MsgServer        s; 
        char            *name;
	double		*valptr;
	double		 timeout;
{
	return msg_agetd(s, name, MsgWait, valptr, timeout);
}

/* Get an string value for the server.  Wait for the reply.
 */
int msg_getstr(s, name, valptr, max, timeout)
        MsgServer        s; 
        char            *name;
	char		*valptr;
	int		 max;
	double		 timeout;
{
	return msg_agetstr(s, name, MsgWait, valptr, max, timeout);
}

/* Get an data block for the server.  Wait for the reply.
 */
int msg_getblk(s, name, valptr, leng, timeout)
        MsgServer        s; 
        char            *name;
	void		*valptr;
        int              leng;
	double		 timeout;
{
	return msg_agetblk(s, name, MsgWait, valptr, leng, timeout);
}

