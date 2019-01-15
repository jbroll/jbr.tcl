/* msgserv.c

 Public side server routines

 */

#include <xos.h>
#include <xfile.h>
#include <sys/time.h>
#include "msg.h"

/* Internal Default Key Callbacks
 */
void isrv_sub();
void isrv_uns();
void isrv_get();
void isrv_lst();
void isrv_tag();

char	*getenv();

char	*msglogger = NULL;

/* #msg_server returns a new server handle and is the first routine to 
   be called on a server program.
 */
MsgServer msg_server(server)
	char	*server;	/* Server name.  This name is an environment
				   variable which contains the server address.
				 */
{
	MsgServer s;
        char    *sok;
        char    *program;
	char    progname[256];
	int	ii,n;

        if ( program = strrchr(server, '/') )
            program++;
        else
            program = server;
	strcpy(progname,program);
	program=progname;
	while ( *program )
	    *program++=toupper(*program);

    msg_debug = getenv("MSGDEBUG") != 0;

    if (  (sok = getenv(progname)) == NULL ) {
        if ( msg_debug ) fprintf(stderr, "No server address in environment : %s\n", progname);
	return NULL;
    }

    Calloc(s, sizeof(struct MsgServer));

    if ( (s->clnts[0].inp = SokOpen(sok, 0, XFREAD | XFCREAT)) == NULL ) {
        if ( msg_debug ) fprintf(stderr, "Cannot open socket at : %s\n", sok);
	Free(s);
	return NULL;
    }

    s->name = strdup(progname);
    s->sok  = strdup(sok);

/*    s->clnts[0].out  = OpenFd(FileFd(s->clnts[0].inp), "r+"); */
    s->clnts[0].type = MsgServerSide;
    s->clnts[0].server = s;
    s->up = 1;
    s->msgid = 0;
    NewString(s->clnts[0].address, server);

    FD_SET(FileFd(s->clnts[0].inp), &s->rfds);

    s->maxfd = FileFd(s->clnts[0].inp);
    s->mapfd[FileFd(s->clnts[0].inp)] = 0;

    s->newclient = NULL;
    s->kilclient = NULL;
    s->error     = NULL;
    s->logfile   = NULL;

    msg_register(s, "sub", 0           , isrv_sub, NULL, "Subscribe to a published value");
    msg_register(s, "uns", 0           , isrv_uns, NULL, "Unsubscribe a subscribed value");
    msg_register(s, "set", MsgNArgs | 3, imsg_set, NULL, "Set a published value");
    msg_register(s, "get", 0           , isrv_get, NULL, "Get a published value");
    msg_register(s, "lst", 0           , isrv_lst, NULL, "List the registered server commands and published values");
    msg_register(s, "tag", 0           , isrv_tag, NULL, "Specify a client tag");

    msg_register(s, "ack", 0, imsg_ack, NULL, "Acknowledge a sucessfully completed command");
    msg_register(s, "nak", MsgNoParseArgs, imsg_nak, NULL, "Acknowledge as error on a command");
    msg_register(s, "log", 0, imsg_log, NULL, "-name filename -format %s -- Specify a msg log");

    s->log = msg_publish(s, "log", MsgStrType, NULL, 0, NULL, NULL, "log server actions");

    msg_loginit(s, NULL);
    return s;
}

/* #msg_register registers a new command with the server.
 */
int msg_register(s, key, flag, func, data, comment)
	MsgServer	 s;		/* Server handle	*/
	char		*key;		/* Command name		*/
	int		 flag;		/* Options flag		*/
	void 	       (*func)();	/* Command function	*/
	void		*data;		/* Closure data for the command	*/
	char		*comment;	/* Command description	*/
{
    if ( s->nkeys >= s->akeys ) {
	s->akeys += 100;

	ReAlloc(s->keys, sizeof(struct Key) * s->akeys);
    }

    s->keys[s->nkeys].name = strdup(key);
    s->keys[s->nkeys].leng = strlen(key);
    s->keys[s->nkeys].flag = flag;
    s->keys[s->nkeys].func = func;
    s->keys[s->nkeys].data = data;
    s->keys[s->nkeys].comm = comment;

    s->nkeys++;

    return 1;
}

/* #msg_fakclient attaches a file handle to the server input loop.  This 
   routine is often used to read in server initialzation commands of macros.
 */
msg_fakclient(s, f, name)
	MsgServer	s;		/* Server Handle	*/
	File		f;		/* Input file handle	*/
	char		*name;		/* Fake name for client	*/
{

	int	i;

    for ( i = 1; i < MsgMaxClients && s->clnts[i].inp != NULL; i++ ) ;

    if ( i == MsgMaxClients ) {
	FPrint(Stderr, "server: too many clients\n");
	return 0;
    }

    if ( (s->clnts[i].inp  = f) == NULL )
	return 0;
    s->clnts[i].server	   = s;
    s->clnts[i].address	   = strdup(name);
    s->clnts[i].out        = stderr;
    FD_SET(FileFd(s->clnts[i].inp), &s->rfds);

    s->maxfd = Max(s->maxfd, FileFd(s->clnts[i].inp));
    s->mapfd[FileFd(s->clnts[i].inp)] = i;

    msg_dbg(s, "Fak Client: %s\n", s->clnts[i].address);

    msg_handler(s, &s->clnts[i]);
    return 1;
}

#ifdef __STDC__
/* #msg_publish makes server variables available for access from the clients.
 */
int msg_publish(
	MsgServer	 s,
	char		*name,		/* Published name of the variable */
	int		 type,		/* Data type of the variable	*/
	void		*buff,		/* Address of the variable	*/
	int		 leng,		/* Buffer length		*/
	MsgValueFunc	 func,		/* Set/Get callback		*/
	void		*data,		/* Closure data for callback	*/
	char		*comment,	/* Variable description			*/
	...)
{
    va_list         args;
    va_start(args, comment);
#else
int msg_publish(va_alist) va_dcl
{
    va_list         args;
 
	MsgServer	 s;
	char		*name;		/* Published name of the variable */
	int		 type;		/* Data type of the variable	*/
	void		*buff;		/* Address of the variable	*/
	int		 leng;		/* Buffer length		*/
	MsgValueFunc	 func;		/* Set/Get callback		*/
	void		*data;		/* Closure data for callback	*/
	char		*comment;	/* Variable description			*/

    va_start(args);

	s		= va_arg(args, MsgServer);
	name;		= va_arg(args, char *);
	type;		= va_arg(args, int);
	*buff;		= va_arg(args, void *);
	leng;		= va_arg(args, int);
	func;		= va_arg(args, MsgValueFunc);
	data;		= va_arg(args, void *);
	comment;	= va_arg(args, char *);
#endif

 {
    	MsgValue value;
	char	formatted[256];
	int	nth;

    vsprintf(formatted, name, args);
    value = msg_lookupval(s, formatted);

    if ( value != NULL ) {
	return 0;
    }

    nth = MsgAddValue(s, formatted, type, buff, leng, func, data, comment, 0);

    if ( type == MsgBusType ) {
	if ( !MsgCastPublish(s, nth) ) return 0;
    }

    return nth + 1;
 }
}


int msg_postnow(s, nth, Valptr) 
	MsgServer        s;
	int		 nth;
	void		*Valptr;	/* Address of the new value	*/
{
	return msg_post(s, &s->values[nth-1], Valptr, 2);
}

int msg_postmrk(s, nth, Valptr) 
	MsgServer        s;
	int		 nth;
	void		*Valptr;	/* Address of the new value	*/
{
	return msg_post(s, &s->values[nth-1], Valptr, 1);
}

int msg_postnth(s, nth, Valptr) 
	MsgServer        s;
	int		 nth;
	void		*Valptr;	/* Address of the new value	*/
{
	return msg_post(s, &s->values[nth-1], Valptr, 0);
}

int msg_post(s, value, Valptr, flag)
	MsgServer        s;
	MsgValue	 value;
	void		*Valptr;	/* Address of the new value	*/
	int		 flag;
{
	int	j;
	void	*valptr = Valptr;
	int	update;

    if ( value == NULL ) {
	msg_dbg(s, "Post to unpublished variable\n");
	return;
    }
    if ( Valptr == NULL ) {
	if ( value->buff == NULL ) {
	    msg_dbg(s, "Post from NULL pointer: %s\n", value->name);
	    return;
	} else			   valptr = value->buff;
    }

    if ( value->buff && value->buff != valptr ) {
	memcpy(value->buff, valptr, value->leng);
    }

    if ( flag == MsgPostNow ) {
		int	j;
		double  clock = msg_clock();

	for ( j = 0; j < value->nsubs; j++ ) {
	    if ( value->subs[j].client   != NULL ) {
		msg_setbytype(value->type
			, s, value->subs[j].client
			, value->name
			, MsgNoAck
			, valptr
			, value->leng
			, 0.0);

		value->subs[j].timeout =
		    clock + Abs(value->subs[j].interval);

		if ( value->subs[j].interval >= 0.0 )
		    value->subs[j].pending = 0;
	    }
	}
    } else {
	if ( value->cach != NULL ) {
	    value->posted |= msg_cache(valptr
				    , value->cach
				    , value->leng
				    , value->type);
	} else {
	    value->posted  = -1;
	}

	if ( flag ) value->posted  = -1;
    }

    return 1;
}



/* #msg_postval posts a new value for a variable and sends the value to all
   subscribed clients.
 */
int msg_postval(s, name, Valptr)
	MsgServer        s;
	char		*name;
	void		*Valptr;	/* Address of the new value	*/
{
    	MsgValue	value = msg_lookupval(s, name);

	return msg_post(s, value, Valptr, 0);
}


/* #msg_addtimer adds a periodic callback poll loop.
 */
int msg_addtimer(s, interval, func, data)
	MsgServer	 s;
	double		 interval;	/* Callback interval	*/
	MsgTimerFunc	 func;		/* Callback		*/
	void		*data;		/* Closure data for the callback */
{
	    int clock;
	    int	i;

	clock = msg_clock();

	for ( i = 0; i < MsgNTimers; i++ ) {
	    if ( s->timers[i].interval == 0.0 ) break;
	}
	if ( i >= MsgNTimers ) return 0;

	s->timers[i].interval	= interval;
	s->timers[i].func 	= func;
	s->timers[i].data	= data;
	s->timers[i].lock	= 0;
	s->timers[i].tid	= msg_nextid() + s->msgid;;

	s->timers[i].timeout	= clock + interval;

	return s->timers[i].tid;
}

/* #msg_remtimer removes a periodic callback that was added by #msg_addtimer.
 */
int msg_deltimer(s, tid)
	MsgServer	s;
	unsigned int	tid;
{

	int	i;

	for ( i = 0; i < MsgNTimers; i++ ) {
	    if ( s->timers[i].tid == tid ) break;
	}
	if ( i >= MsgNTimers )
		return 0;

	s->timers[i].interval	= 0.0;
	s->timers[i].tid	= 0;

	return 0;
}

/* #msg_shutdown closes a server of client connection and frees all memory.
 */
msg_shutdown(s)
	MsgServer	s;
{
	int	i;

    for ( i = 0; i < MsgMaxClients; i++ ) {
	if ( s->clnts[i].inp != NULL ) {
	    msg_kilclient(s, MsgClient(s, i));
	}
    }

    Free(s);
}

void *msg_RO(s, op, name, data, buff, leng)
	MsgServer       s;
	int		op;
	char		*name;
	void		*data;
	void		*buff;
	int		*leng;
{
	if ( op == MsgGetVal )  return buff;
	else			return NULL;
}

void msg_up(s,name)
	MsgServer       s;
	char 		*name;
{
    char initfile[128];
    char    progname[128];
    char    *program;
    char *fptr;
    File ifp;
    fptr=NULL;
        if ( program = strrchr(s->name, '/') )
            program++;
        else
            program = s->name;
	strcpy(progname,program);
	program=progname;
	while ( *program )
	    *program++=tolower(*program);
	program=progname;
	if( name != NULL ) 
	    sprintf(program+strlen(progname),"_%s",name);
    	fptr = getenv("MSGINITDIR");
	if( fptr != NULL )
	    sprintf(initfile,"%s/%s.rc",fptr,program);
	else 
	    sprintf(initfile,"%s.rc",program);
 	ifp = fopen(initfile,"r");
	if ( ifp == NULL ) {
	    	sprintf(initfile,".%s", program);
		ifp = fopen(initfile,"r");
	}
	if( ifp != NULL )
            msg_fakclient(s, ifp, "server initialization");
}

int  msg_isup(s) 
      MsgServer       s;
{
      return s->up;
}

