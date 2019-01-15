/* msg.c
 */

#include <xos.h>
#include <xfile.h>
#include <sys/signal.h>
#include <pthread.h>
#include "msg.h"

double atof();
char *strdup();
char *getenv();

#ifdef __STDC__
#include <stdarg.h>
#else
#include <varargs.h>
#endif

typedef (*vvector)();

int  msg_debug = 0;
int  msg_errno = 0;
char msg_errstr[MsgErrLen];
vvector msg_errhandler = NULL;
void   *msg_errdata    = NULL;

double msg_reopen();

void msg_log(MsgServer s, Client c, char *type, char *line) {
	char date[32];
	char buff[512];

	char addr[128];
	char *col;

    if ( !s->log ) { return; } 

    strcpy(addr, c->address);
    if ( col = strchr(addr, ':') ) { *col = '\0'; }
    

    /* date server socket peername tag command	*/
    snprintf(buff, 512, "%s %s %s %s %s %s %s"
	, msg_date(date), s->name, s->sok, addr, c->tag, type, line);

    msg_postnow(s, s->log, buff);
}

msg_seterrhandler(handler, data)
	vvector	handler;
	void	*data;
{
	msg_errhandler = handler;
	msg_errdata    = data;
}

msg_seterrdata(s, errdata)
	MsgServer	s;
	void		*errdata;
{
	s->errdata = errdata;
}

int msg_error(s, n, str)
	MsgServer	s;
	int		n;
	char		*str;
{
    strncpy(msg_errstr, str, MsgErrLen);
    msg_errno = n;

    if ( msg_errhandler != NULL )
	(*msg_errhandler)(n, str, msg_errdata, s != NULL ? s->errdata : NULL);

    return n;
}
	

struct Key msg_comment;

/* #msg_newclient is an internal routine which accepts a new client from the 
   listened server socket.
 */
msg_newclient(s)
	MsgServer	s;		/* Server handle	*/
{

	int	i;

    for ( i = 1; i < MsgMaxClients && s->clnts[i].inp != NULL; i++ ) ;

    if ( i == MsgMaxClients ) {
	FPrint(Stderr, "server: too many clients\n");
	return 0;
    }

    if ( (s->clnts[i].inp  = Accept(s->clnts[0].inp, "r+", &(s->clnts[i].address))) == NULL ) {
    	msg_dbg(s, "New Client: Accept rejected");
	return 0;
    }
    s->clnts[i].server = s;
    s->clnts[i].tag    = "-";

    msg_log(s, &s->clnts[i], "new", s->clnts[i].address);


    s->clnts[i].out        = OpenFd(FileFd(s->clnts[i].inp), "r+");

    FD_SET(FileFd(s->clnts[i].inp), &s->rfds);

    s->maxfd = Max(s->maxfd, FileFd(s->clnts[i].inp));
    s->mapfd[FileFd(s->clnts[i].inp)] = i;

    msg_dbg(s, "New Client: %s #%d on fd %d"
		, s->clnts[i].address
    		, i
		, FileFd(s->clnts[i].inp));

    if (s->newclient != NULL ) {
        s->clnts[i].data = (*s->newclient)(s, &s->clnts[i], s->newdata);
    }

    return 1;
}

msg_reminput(s, file)
	MsgServer	 s;		/* Server handle	*/
	File		 file;
{
    msg_kilclient(s, &s->clnts[s->mapfd[FileFd(file)]]);
}

msg_addinput(s, file, func, data, mode)
	MsgServer	 s;		/* Server handle	*/
	File		 file;
	MsgInputFunc	 func;
	void		*data;
	int		 mode;
{
    	MsgAddInput	inp;
	int	i;

    for ( i = 1; i < MsgMaxClients && s->clnts[i].inp != NULL; i++ ) ;

    if ( i == MsgMaxClients ) {
	FPrint(Stderr, "server: too many clients\n");
	return 0;
    }

    s->clnts[i].type    = MsgAddInpType;
    s->clnts[i].inp     = file;
    s->clnts[i].out     = NULL;
    s->clnts[i].address = NULL;

    s->clnts[i].inp = file;
    s->clnts[i].out = NULL;

    FD_SET(FileFd(s->clnts[i].inp), &s->rfds);

    s->maxfd = Max(s->maxfd, FileFd(s->clnts[i].inp));
    s->mapfd[FileFd(s->clnts[i].inp)] = i;

    msg_dbg(s, "New Input : #%d on fd %d"
    		, i
		, FileFd(s->clnts[i].inp));

    Malloc(inp, sizeof(struct MsgAddInput));
    s->clnts[i].data = inp;

    inp->func = func;
    inp->data = data;

    s->clnts[i].server = s;
    return 1;
}

/* #msg_kilclient is an internal routine which removes a client from the 
   server poll loop.
 */
msg_kilclient(s, c)
	MsgServer	s;		/* Server handle	*/
	Client		c;		/* Client handle	*/
{
	int	j, k;

    msg_dbg(s, "Kil Client: %s", c->address);

    if (s->kilclient != NULL ) {
	(*s->kilclient)(s,c,s->kildata);
    }
    if ( c == &s->clnts[0] ) {
	/* This is a client */
	s->up = 0;

	/* Mark all asyncs to this server as killed
	 */
	for ( k = 0; k < s->nasyncs; k++ ) {
	    if ( s->asyncs[k].group && !s->asyncs[k].status ) {
		s->asyncs[k].status = MsgErrKilClnt;
		strcpy(s->asyncs[k].error, "msg: connection killed.");
	    }
	}
	if ( s->state ) {
	    (*s->state)(s, s->sdata, 0);
	}
	s->up  = 0;
	if ( !s->tid ) s->tid = msg_addtimer(s, 1.0, msg_reopen, NULL);
    } else {
	msg_log(s, c, "kil", c->address);
    }

    /* Kill any subscriptions for this client
     */
    for ( j = 0; j < s->nvalues; j++ ) {
	if ( c == &s->clnts[0] ) {
	    if ( s->values[j].type == MsgBusType ) {
		msg_reminput(s, s->values[j].file);
	    }
	} else {
	    for ( k = 0; k < s->values[j].nsubs; k++ ) {
		if ( s->values[j].subs[k].client == c ) {
		    s->values[j].subs[k].client = NULL;
		}
	    }
	}
    }


    if ( c->inp ) {
	FD_CLR(FileFd(c->inp), &s->rfds);

	if ( FileFd(c->inp) == s->maxfd ) {
	    int	i;
	    s->maxfd = FileFd(s->clnts[0].inp);

	    for ( i = 1; i < MsgMaxClients; i++ )
		if ( s->clnts[i].inp != NULL )
		    s->maxfd = Max(s->maxfd, FileFd(s->clnts[i].inp));
	}
	Close(c->inp);
    }

    if ( c->address ) Free(c->address);
    if ( c->out && c->out != stderr ) { Close(c->out); }

    c->inp = NULL;
    c->out = NULL;
}

msg_newcallback(s, callback, calldata) 
	MsgServer	 s;
	void		*(*callback)();
	void		*calldata;
{
	s->newclient = callback;
	s->newdata   = calldata;
}

msg_kilcallback(s, callback, calldata) 
	MsgServer	s;
	void		(*callback)();
	void		*calldata;
{
	s->kilclient = callback;
	s->kildata   = calldata;
}

void *msg_clientdata(c) 
	Client	c;
{
	return c->data; 
}



msg_handler(s, c)
	MsgServer	s;
	Client		c;
{
	char	 line[MsgBufferSize];
	Key	 cmd;
	int	 red;

	int	 msgid;
	char	*argv[MsgMaxArgs];
	int	 argc;
	int	 i;

    for ( i = 0; i < MsgBufferSize; i++ ) line[i] = '\0';

    while ( 1 ) {
	red = ReadLine(c->inp, line, MsgBufferSize);

	if ( red <= 0 ) {
	    msg_kilclient(s, c);
	    break;
	}
	while ( line[red-1] == '\n' 
	     || line[red-1] == ' '
	     || line[red-1] == '\t'
	     || line[red-1] == '\r'  ) {
		line[red-1] = '\0';
		red--;
		if ( !red ) break;
	}
	msg_dbg(s, line);
	if ( s->log ) { msg_log(s, c, "cmd", line); }

	if ( *line ) {
	    argc = MsgMaxArgs;
	    if ( (cmd = msg_parse(s, line, &msgid, &argc, argv)) == NULL ) {
		msg_nak(c, msgid, "unknown command: %s", line);
		msg_dbg(s,"unknown command");
	    } else {
		if ( cmd != &msg_comment && cmd->func != NULL ) {
		    (*cmd->func)(s, c, msgid, cmd->data, argc, argv);
		}

		/* On the client side an Ack may be followed by
		   interpacked data returning from the server.

		   Return to give the client a chance to read it.
		 */
		if ( cmd->func == imsg_ack && c->type == MsgClientSide ) {
			break;
		}
	    }
        }

	if ( c->inp == NULL || !FileLeft(c->inp) ) break;
    }

    return 1;
}

int msg_sizeof(type, leng)
	int	type;
	int	leng;
{
    switch ( type ) {
     case MsgNulType:	return 0;
     case MsgIntType:	return sizeof(int);
     case MsgFltType:	return sizeof(float);
     case MsgDblType:	return sizeof(double);
     case MsgBlkType:	return leng;
     case MsgStrType:	return leng;
     case MsgBusType:   return leng;
     default:
	FPrint(Stderr, "msg: ileagle type in sizeof\n");
    }
}

MsgAddValue(s, name, type, buff, leng, func, data, comment, time)
	MsgServer	 s;
	char		*name;
	int		 type;
	void		*buff;
	int		 leng;
	void	      *(*func)();
	void		*data;
	char		*comment;
	double		 time;
{
	MsgValue	value;

    if ( s->nvalues >= s->avalues ) {
	s->avalues += 100;
	ReAlloc(s->values, sizeof(struct MsgValue) * s->avalues);
    }

    value = &s->values[s->nvalues];

    leng = msg_sizeof(type, leng);

    value->name  = strdup(name);
    value->type  = type;
    value->buff  = buff;
    value->leng  = leng;
    value->func  = func;
    value->data  = data;
    value->nsubs = 0;
    value->subs  = NULL;
    value->posted= 0;
    if( comment != NULL )
        value->comm = strdup(comment);
    else
	value->comm = NULL;

    value->time  = time;
    value->cach  = NULL;

    if ( type != MsgBusType && !(type == MsgBlkType && leng <= 0) ) {
	Calloc(value->cach, leng);
	if ( buff ) msg_cache(value->buff, value->cach, value->leng, value->type);
	else	    memset(value->cach, 0,  value->leng);
    }

    return s->nvalues++;
}

MsgValue msg_lookupval(s, name)
	MsgServer	 s;
	char		*name;
{
	int	i;

    for ( i = 0; i < s->nvalues; i++ ) {
	if ( !strcmp(name, s->values[i].name) ) return &s->values[i];
    }

    return NULL;
}

int msg_nthvalue(s, name)
	MsgServer	 s;
	char		*name;
{
	int	i;

    for ( i = 0; i < s->nvalues; i++ ) {
	if ( !strcmp(name, s->values[i].name) ) return i+1;
    }

    return 0;
}



int msg_syncs(s, group, msgid, type, valptr, leng, timeout)
	MsgServer        s;
	int              group;
	int		 type;
	void		*valptr;
	int		 leng;
	double		 timeout;
{
    if ( group ) {
	msg_addasync(s, group, msgid, type, valptr, leng, timeout);

	if ( group == MsgWait) {
	    return msg_waitloop(&s, 1, MsgWait, msgid, timeout);
	}
    }

    return 1;
}

msg_addasync(s, group, msgid, type, buff, leng, timeout)
	MsgServer	 s;
	int		 group;
	int		 msgid;
	int		 type;
	void		*buff;
	double		 timeout;
{
	int	i;
	int	a;
	double clock;

    clock = msg_clock();

    for ( i = 0; i < s->nasyncs; i++ ) {
	if ( s->asyncs[i].group == 0 ) break;
    }
    a = i;

    if ( i >= s->nasyncs ) {
    	s->nasyncs += 100;

    	ReAlloc(s->asyncs, sizeof(struct Async) * s->nasyncs);
	for ( i++; i < s->nasyncs; i++ )
	    s->asyncs[i].group = 0;
    }

/* fprintf(stderr, "Que msg on 0x%x msgid = %d async = 0x%x\n"
	, s, msgid, &s->asyncs[a]);
*/

    s->asyncs[a].group	 = group;
    s->asyncs[a].msgid   = msgid;
    s->asyncs[a].type  	 = type;
    s->asyncs[a].buff	 = buff;
    s->asyncs[a].leng  	 = leng;
    s->asyncs[a].timeout = timeout + clock;
    s->asyncs[a].status	 = 0;
}


Key msg_parse(s, line, msgid, argc, argv)
	MsgServer	 s;
	char		*line;
	int		*msgid;
	int		*argc;
	char		*argv[];
{
	Key	 cmd;
	char	*pb = line;
	int	 i;

	int	 max = *argc;

    while ( *line == ' ' || *line == '\t' ) line++;
    if ( *line == '\0' 
      || *line == '#'
      || *line == '\n' ) return &msg_comment;

    *msgid = strtol(pb, &pb, 0);

    while ( *pb == ' ' || *pb == '\t' ) pb++;

    for ( i = 0; i < s->nkeys; i++ ) {
	if ( (  *(pb + s->keys[i].leng) == ' ' 
	     || *(pb + s->keys[i].leng) == '\0' )
	  && !strncmp(pb, s->keys[i].name, s->keys[i].leng) ) break;
    }
    if ( i == s->nkeys ) return NULL;

    cmd = &s->keys[i];

    if ( cmd->flag & MsgNoParseArgs ) {
	 argv[0] = pb;
	 argv[1] = &pb[s->keys[i].leng+1];
	*argc    = 2;

	 return cmd;
    }

    if ( cmd->flag & MsgNArgs ) {
	max = cmd->flag & 0xFF;
    }

    for ( i = 0; i < max && *pb; i++ ) {
		int	quote = 0;
		int	c;

	while ( *pb == '\r' || *pb == '\n' || *pb == ' ' || *pb == '\t' ) {
	    *pb = '\0';
	     pb++;
	}

	if ( *pb == '\0' ) break;

	argv[i] = pb;

	c = 0;
	quote = (cmd->flag & MsgNArgs && i == max-1);
	while ( *pb 
	    && (quote
              || (*pb != '\r' && *pb != '\n' && *pb != ' ' && *pb != '\t')) ) {

	    if ( quote ) {
		if ( *pb == quote ) {
		    quote = 0;
		    pb++;

		    continue;
		}
	    } else {
		if ( *pb == '\'' || *pb == '"' ) {
		    quote = *pb;
		    pb++;

		    continue;
		}

		if ( *pb == '#' ) {
			*pb = '\0';
			break;
		}
	    }
	    argv[i][c++] = *pb++;
	}

	if ( *pb == '\0' ) {
	    argv[i][c] = '\0';
	    i++;
	    break;
	}
	argv[i][c] = '\0';
	pb++;
    }
    *argc = i;

    return cmd;
}

msg_format(c, msgid, cmd, format, args)
	Client	 c;
	int	 msgid;
	char	*cmd;
	char	*format;
	va_list  args;
{
	int n;

    msg_logline(c, msgid, cmd, format, args);

    if ( !msgid ) return;

    fprintf(c->out, "%u %s ", msgid, cmd);

    if ( format ) vfprintf(c->out, format, args);
    fprintf(c->out, "\n");
    Flush(c->out);

    if ( msgid && c->server->log ) {
	char buff[512];

	n =  snprintf(buff    , 512,   "%u %s ", msgid, cmd);
	    vsnprintf(&buff[n], 512-n, format, args);
	msg_log(c->server, c, cmd, buff);
    }
}

#ifdef __STDC__
int msg_rpy(Client c, int msgid, char *cmd, char *format, ...)
{
    va_list         args;
    va_start(args, format);
#else
int msg_rpy(va_alist) va_dcl
{
    va_list         args;
 
    Client c;
    int	   msgid;
    char  *cmd;
    char  *format;
    va_start(args);
    c      = va_arg(args, Client);
    msgid  = va_arg(args, int);
    cmd    = va_arg(args, int);
    format = va_arg(args, char *);
#endif

    msg_format(c, msgid, cmd, format, args);
    return 1;
}

#ifdef __STDC__
/* ack a message */
int msg_ack(Client c, int msgid, char *format, ...)
{
    va_list         args;
    va_start(args, format);
#else
int msg_ack(va_alist) va_dcl
{
    va_list         args;
 
    Client c;
    int	   msgid;
    char  *format;
    va_start(args);
    c      = va_arg(args, Client);
    msgid  = va_arg(args, int);
    format = va_arg(args, char *);
#endif

    if ( !c->inp ) return 0;

    msg_format(c, msgid, "ack", format, args);
    return 1;
}

#ifdef __STDC__
/* nak a message */
int msg_nak(Client c, int msgid, char *format, ...)
{
    va_list         args;
    va_start(args, format);
#else
int msg_nak(va_alist) va_dcl
{
    va_list         args;
 
    Client c;
    int	   msgid;
    char  *format;
    va_start(args);
    c      = va_arg(args, Client);
    msgid  = va_arg(args, int);
    format = va_arg(args, char *);
#endif

    if ( !c->inp ) return 0;

    msg_format(c, msgid, "nak", format, args);
    return 0;
}

Async msg_lookupasync(s, msgid)
	MsgServer	s;
	int		msgid;
{
	    int	k;

	for ( k = 0; k < s->nasyncs; k++ ) {
	   if ( s->asyncs[k].msgid == msgid ) {
		return &s->asyncs[k];
	   }
	}

	return NULL;
}

void imsg_nak(s, c, msgid, data, argc, argv)
	MsgServer	 s;
	Client		 c;
	void		*data;
	int		 msgid;
	int		 argc;
	char		*argv[];
{
	Async	a;

    if ( (a = msg_lookupasync(s, msgid)) == NULL ) {
	FPrint(Stderr, "No buffer for nak: %d\n", msgid);
	return;
    }

    strncpy(a->error, argv[1], MsgErrLen);
    a->status = -1;
}


void imsg_ack(s, c, msgid, data, argc, argv)
	MsgServer	 s;
	Client		 c;
	void		*data;
	int		 msgid;
	int		 argc;
	char		*argv[];
{
	int	leng;
	char	ch;
	Async	a;

    int blk = !strncmp(argv[0], "blk", 3);

    if ( (a = msg_lookupasync(s, msgid)) == NULL ) {
	if ( s->clnts[0].type == MsgServerSide ) {
	    msg_ack(c, msgid, "");
	    return;
	}

          if ( blk && argc == 2 ) {
	    leng = atoi(argv[1]);

	    msg_dbg(s, "unexpected data block: %d", leng);

	    while ( leng-- ) 
		Read(c->inp, &ch, 1, 1);
	}

	return;
    }

    if ( a->type != MsgNulType && argc != 2 ) {
	a->status = -1;
	return;
    }

    a->status = 1;

    if ( a->type != MsgBlkType ) {
	if ( blk ) {
	    msg_dbg(s, "unexpected data block: %d", leng);
	}
	switch ( a->type ) {
	 case MsgNulType:	return;
	 case MsgIntType:	*((int    *) a->buff) = atoi(argv[1]);	break;
	 case MsgFltType:	*((float  *) a->buff) = atof(argv[1]);	break;
	 case MsgDblType:	*((double *) a->buff) = atof(argv[1]);	break;
	 case MsgStrType:	strncpy((char *) a->buff, argv[1], a->leng);	break;
	 default:
	    FPrint(Stderr, "ack: illegal type in ack\n");
	    a->status = -1;
	}
    } else {
	if ( !blk ) {
	    msg_dbg(s, "expected data block: %d", a->leng);
	}
	leng = atoi(argv[1]);

	if ( leng > a->leng ) {
	    msg_dbg(s, "data block length mismatch: expected %d got %d"
		   	, a->leng, leng);
	}

	Read(c->inp, a->buff, Min(leng, a->leng), 1);
	while ( leng > 	a->leng ) 
	    Read(c->inp, &ch, 1, 1);

	a->status = Min(leng, a->leng);
    }
}

void imsg_set(s, c, msgid, data, argc, argv)
	MsgServer	 s;
	Client		 c;
	void		*data;
	int		 msgid;
	int		 argc;
	char		*argv[];
{
		MsgValue	 value;
		char		*valuestr = "";

	if ( argc >= 2 ) {
	    if ( (value = msg_lookupval(s, argv[1])) == NULL ) {
		if ( c->type == MsgServerSide ) {
		    msg_nak(c, msgid, "value is not published: %s", argv[1]);
		} else {
		    msg_nak(c, msgid, "value is not subscribed: %s", argv[1]);
		}
		return;
	    }
	}

	if ( argc == 1 || (argc == 2 && value->type != MsgStrType) ) {
	    msg_nak(c, msgid, "wrong number of args to set: %s"
			, argc == 2 ? argv[1] : "");
	    return;
	}

	if ( argc == 3 ) {
	     valuestr = argv[2];
	}

	if ( value->buff == NULL && value->func == NULL ) {
	    msg_nak(c, msgid, "can't set %s", value->name);
	    return;
	}

    {
		void *buff = value->buff;
		int   leng = value->leng; 

	if ( value->type == MsgBlkType ) {
		leng = atoi(argv[2]);

	    if ( value->leng < 0 ) {
		leng=Min(leng,Abs(value->leng) );
	    } else {
		if ( leng != value->leng ) {
			char	ch;
			int	i;

		    /* Read the ugly block off the socket.
		     */
		    for ( i = 0; i < leng; i++ )
			    Read(c->inp, &ch, 1, 1);

		    msg_nak(MsgClient(s, i), msgid
	, "data block length mismatch: expected %d got %d", value->leng, leng);
		    return;
		}
	    }
	}

	if ( value->buff == NULL )  Malloc(buff, leng);

	switch ( value->type ) {
	 case MsgIntType: *((int    *) buff) = atoi(valuestr);	break;
	 case MsgFltType: *((float  *) buff) = atof(valuestr);	break;
	 case MsgDblType: *((double *) buff) = atof(valuestr);	break;
	 case MsgStrType: strncpy(buff, valuestr, value->leng);
			  ((char *)buff)[value->leng-1] = '\0'; break;
		
	 case MsgBlkType: Read(c->inp, buff, leng, 1);	break;
	}

	if ( value->func )
	    if ( !(*value->func)(s, MsgSetVal, value->name, value->data
			, buff, leng) ) {
	        if ( (value = msg_lookupval(s, argv[1])) == NULL ) {
			error("lost value pointer in user function call");
		}
	        msg_nak(c, msgid, "can't set value: %s", value->name);
	        return;
	    }

        msg_ack(c, msgid, NULL);

	/* 
	 * Lookup the value again, it may have been realloced
	 */
	if ( (value = msg_lookupval(s, argv[1])) == NULL ) {
		error("lost value pointer in user function call");
	}

	/* Mark the value as posted from this client.
	 */
	if ( value->cach != NULL ) {
	    if ( msg_cache(buff, value->cach, value->leng, value->type) ) {
		value->posted = c - s->clnts;
	    } 
	} else {
		value->posted = c - s->clnts;
	}

        if ( value->buff == NULL && value->leng > 0 ) Free(buff);
    }
}


void imsg_log(s, c, msgid, data, argc, argv)
	MsgServer	 s;
	Client		 c;
	void		*data;
	int		 msgid;
	int		 argc;
	char		*argv[];
{
		MsgValue	 value;

	if ( argc > 2 ) {
	    msg_nak(c, msgid, "too many args to log: %s %s"
			, argv[1], argv[2]);
	    return;
	}
	if ( argc < 2 ) {
	    msg_nak(c, msgid, "not enough args to log - needs a filename");
	    return;
	}

	msg_loginit(s, argv[1]);
        msg_ack(c, msgid, NULL);

}

msg_cache(v1, v2, length, type)
	void		*v1;
	void		*v2;
	int		 length;
	int		 type;
{

    if ( type == MsgStrType ) {
	if ( strncmp(v1, v2, length) ) {
	     strncpy(v2, v1, length);
	    return -1;
	}
    } else {
	if ( memcmp(v1, v2, length) ) {
	     memcpy(v2, v1, length);
	    return -1;
	}
    }
    return  0;
}

msg_setbytype(type, s, c, name, group, valptr, leng, timeout)
	int		 type;
	MsgServer	 s;
	Client		 c;
	char		*name;
	int		 group;
	void		*valptr;
	int		 leng;
	double		 timeout;
{
    if ( valptr == NULL ) return;

    switch ( type ) {
     case MsgIntType:
	msg_xseti(s, c, name, group, *((int    *) valptr), timeout);
	break;
     case MsgFltType:
	msg_xsetd(s, c, name, group, *((float  *) valptr), timeout);
	break;
     case MsgDblType:
	msg_xsetd(s, c, name, group, *((double *) valptr), timeout);
	break;
     case MsgStrType:
	msg_xsetstr(s, c, name, group, (char *) valptr, timeout);
	break;
     case MsgBlkType:
	msg_xsetblk(s, c, name, MsgNoAck, (char *) valptr, leng, timeout);
	break;
     case MsgBusType: break;
     default:
	fprintf(stderr, "msg: bad type in post: %c\n", type);
    }
}

/* SERVER Side internal routines ---------------------------------------------*/


void isrv_sub(s, c, msgid, data, argc, argv)
	MsgServer	 s;
	Client		 c;
	void		*data;
	int		 msgid;
	int		 argc;
	char		*argv[];
{
	MsgValue	value;
	Subsc	 	sub;
	double		timeout;

	if ( argc != 2 && argc != 3 && argc != 4 ) {
	    msg_nak(c, msgid, "wrong number of args in subscription");
	    return;
	}

	if ( (value = msg_lookupval(s, argv[1])) == NULL ) {
            msg_nak(c, msgid, "value is not published: %s", argv[1]);
	    return;
	}

	msg_dbg(s, "sub: %s\n", argv[1]);

	if ( value->type == MsgBlkType ) {
	    if ( argc != 4 ) {
	        msg_nak(c, msgid, "no block length in subscription");
		return;
	    }
	    if ( atof(argv[3]) != value->leng ) {
	        msg_nak(c, msgid, "block length in mismatch in subscription: expected %d got %d", value->leng, atoi(argv[1]));
		return;
	    }
	}

	if ( argc == 2 ) {
	    timeout = 0.0;
	} else {
	    timeout = atof(argv[2]);
	}

	msg_dbg(s, "sub: %s %f\n", argv[1], timeout);

/*
	if ( timeout < 0.0 && value->buff == NULL ) {
	    msg_nak(c, msgid, "cannot create periodic subscription to variable %s with no buffer", argv[1]);
	    return;
	}
 */

	MsgAddSubsc(value, c, timeout);

	msg_ack(c, msgid, NULL);
	if ( strcmp(value->name, "log") ) {
	    msg_setbytype(value->type
			, s, c
			, value->name
			, MsgNoAck
			, value->cach
			, value->leng
			, 0.0);
	}
}


void  isrv_uns(s, c, msgid, data, argc, argv)
	MsgServer	 s;
	Client		 c;
	void		*data;
	int		 msgid;
	int		 argc;
	char		*argv[];
{
        MsgValue    	value;
        Subsc    	sub;
	int		i;

	if ( argc != 1 ) msg_nak(c, msgid, "no value named in unsubscribe");

        if ( (value = msg_lookupval(s, argv[1])) == NULL ) {
            msg_nak(c, msgid, "value is not published: %s", argv[1]);
        }

	if ( (sub   = MsgLookupSubsc(value, c, &i)) == NULL ) {
            msg_nak(c, msgid, "value is not currently  subscribed: %s", argv[1]);
	    return;
        }

	msg_ack(c, msgid, NULL);

	Free(sub);
	value->subs[i].client = NULL;
}

void  isrv_tag(s, c, msgid, data, argc, argv)
	MsgServer	 s;
	Client		 c;
	void		*data;
	int		 msgid;
	int		 argc;
	char		*argv[];
{
        MsgValue    	value;
        Subsc    	sub;
	int		i;

	if ( argc != 2 ) {
	    msg_nak(c, msgid, "no value for tag");
	    return;
	}

	c->tag = strdup(argv[1]);

	msg_ack(c, msgid, NULL);
}

void  isrv_get(s, c, msgid, data, argc, argv)
	MsgServer	 s;
	Client		 c;
	void		*data;
	int		 msgid;
	int		 argc;
	char		*argv[];
{
	MsgValue	 value;

    if ( argc < 1 ) {
	msg_nak(c, msgid, "no value named in get");
	return;
    }

    if ( (value = msg_lookupval(s, argv[1])) == NULL ) {
	msg_nak(c, msgid, "value is not published: %s", argv[1]);
	return;
    }

    if ( value->func ) {
	data = (*value->func)(s, MsgGetVal
			, value->name, value->data, value->buff, &value->leng);
	/* 
	 * Lookup the value again, it may have been realloced
	 */
        value = msg_lookupval(s, argv[1]);

    } else {
	data = value->buff != NULL ? value->buff : value->cach;
    }

    if ( data == NULL ) {
	msg_nak(c, msgid, "value is write only");
	return;
    }

    if ( value->type == MsgBlkType ) {
	    int leng;

	if ( argc != 3 ) {
	    msg_nak(c, msgid, "no block length in get");
	    return;
	}

	leng = atoi(argv[2]);

	if ( leng < value->leng ) {
	    msg_nak(c, msgid, "data block length too short: expected %d got %d", value->leng, leng);
	    return;
	}
    } else
	if ( argc != 2 ) {
	    msg_nak(c, msgid, "too many args to get");
	    return;
	}

    if ( value->cach != NULL ) msg_cache(data
					, value->cach
					, value->leng
				, value->type);

    switch ( value->type ) {
     case MsgIntType: msg_ack(c, msgid, "%d"   , *((int    *) data));	break;
     case MsgFltType: msg_ack(c, msgid, "%.15g", *((float  *) data)); 	break;
     case MsgDblType: msg_ack(c, msgid, "%.15g", *((double *) data)); 	break;
     case MsgStrType: msg_ack(c, msgid, "%s"   ,   (char   *) data);	break;
     case MsgBlkType: {
	      char *d = (char *) data;
	      int bytes = 0;

	msg_rpy(c, msgid, "blk", "%d"   , value->leng);

	while ( bytes < value->leng ) {
	    bytes += Write(c->out, &d[bytes], 1, value->leng - bytes);
	}
        Flush(c->out);
     }
    }

    if ( value->func ) {
        (*value->func)(s, MsgLokVal, value->name, value->data, value->buff, &value->leng);
    }
}

void  isrv_lst(s, c, msgid, data, argc, argv)
	MsgServer	 s;
	Client		 c;
	void		*data;
	int		 msgid;
	int		 argc;
	char		*argv[];
{

	int	j;

    msg_ack(c, msgid, NULL);
    FPrint(c->out, "server	%s	%s\n", s->name, s->sok);

    /* %format :units -- description */
    for ( j = 0; j < s->nvalues; j++ ) {
	FPrint(c->out, "published	%s	%s\n"
			, s->values[j].name
			, s->values[j].comm ? s->values[j].comm : "");
    }

    /* arg%format:units	arg -- description */

    for ( j = 0; j < s->nkeys; j++ ) {
	FPrint(c->out, "registered	%s	%s\n"
			, s->keys[j].name
			, s->keys[j].comm ? s->keys[j].comm : "");
    }

    FPrint(c->out, "----LIST----\n");
    Flush(c->out);
    return;
}


MsgAddSubsc(v, client, timeout)
	MsgValue		 v;
	Client		 client;
	double		 timeout;
{
	int	i;

    for ( i = 0; i < v->nsubs; i++ ) 
	if ( v->subs[i].client == NULL ) break;

    if ( i >= v->nsubs ) {
	    int j = i;

    	v->nsubs += 100;

    	ReAlloc(v->subs, sizeof(struct MsgValue) * v->nsubs);

	for ( ; j < v->nsubs; j++ )
	    v->subs[j].client = NULL;
    }

    v->subs[i].client  = client;
    v->subs[i].timeout = 0.0;
    v->subs[i].interval= timeout;
    v->subs[i].pending = 1;
}


Subsc	MsgLookupSubsc(v, c, in)
	MsgValue 		 v;
	Client	 	 c;
	int 		*in;
{
        int     i;

    for ( i = 0; i < v->nsubs; i++ ) {
        if ( v->subs[i].client == c ) {
	    *in = i;
            return &v->subs[i];
        }
    }

    return NULL;
}


int msg_alarm;
void msg_sighandler() {
	msg_alarm = 1;
}

static int	msg_alarmed = 0;


double msg_reopen(s)
	MsgServer	s;
{
	double	interval;
	int i;

    if ( s->up ) {
	msg_dbg(s, "reopen: already up on %s",s->name);
	return 0;
    }
    msg_dbg(s, "DEBUG reopen: on %s",s->name);

    if ( !msg_alarmed ) {
	sigset_t        mask;
	sigfillset(&mask);
	SigAction(SIGALRM, msg_sighandler, &mask, 0);

	msg_alarmed = 1;
    }

    if ( s->clnts[0].inp != NULL ) { Close(s->clnts[0].inp); }
    if ( s->clnts[0].out != NULL ) { Close(s->clnts[0].out); }

    msg_alarm = 0;
    alarm(2);

    if ( (s->clnts[0].inp  = SokOpen(s->sok, 0, XFREAD | XFWRITE)) != NULL ) {
        msg_dbg(s, "reopen: %s on fd = %d", s->name, FileFd(s->clnts[0].inp));

        alarm(0);

        s->clnts[0].out    = OpenFd(FileFd(s->clnts[0].inp), "r+");
        s->clnts[0].address= strdup(s->name);
	FD_SET(FileFd(s->clnts[0].inp), &s->rfds);

	s->maxfd = FileFd(s->clnts[0].inp);
        s->mapfd[FileFd(s->clnts[0].inp)] = 0;

	s->up  = 1;

	msg_command(s, MsgCmdType, NULL, 0, MsgNoAck, 0, "tag %s", s->clnts[0].tag);

#define MSGGRP 4
	for ( i = 0; i < s->nvalues; i++ ) {
	    s->up  = 1;

	    if ( s->values[i].type == MsgBlkType ) {
	      msg_quemsg(s, &s->clnts[0]
			    , MsgNulType, NULL, 0
			    , MSGGRP, 10.0, "sub %s %g %d\n"
			    , s->values[i].name
			    , s->values[i].time
			    , s->values[i].leng);
	    } else {
	      msg_quemsg(s, &s->clnts[0]
			    , MsgNulType, NULL, 0
			    , MSGGRP, 10.0, "sub %s %g\n"
			    , s->values[i].name
			    , s->values[i].time );
	    }
	    if ( s->values[i].type == MsgBusType ) {
		MsgCastConnect(s, &s->values[i]);
	    }
	}
	if ( s->nvalues ) { 
	    if ( msg_waitloop(&s, 1, MSGGRP, 0, 10.0) <= 0 ) {
		
    	        if ( s->tid )  msg_deltimer(s, s->tid);
		s->tid = 0;

		msg_kilclient(s, &s->clnts[0]);

        	msg_dbg(s, "reopen: %s -- Error in subscriptions", s->name);
		goto ErrorInSubs;
	    }
	}

        if ( !s->state || ( s->state && (*s->state)(s, s->sdata, 1) ) ) {
	    if ( s->tid ) {
		msg_deltimer(s, s->tid);
	    	s->tid = 0;
	    }
	    s->up  = 1;

	    msg_dbg(s, "reopen: opened server %s", s->sok);
	    return 0.0;
	}
    }

ErrorInSubs:

    alarm(0);

    if ( msg_alarm == 0 )
	interval = 1.0;
    else
	interval = 60.0;

    s->up  = 0;
    if ( !s->tid ) {
	if ( !(s->tid = msg_addtimer(s, interval, msg_reopen, NULL)) ) {
    	    msg_dbg(s, "reopen: addtimer fails!!!!\n");
        }
    }

    msg_dbg(s, "reopen: failed, try again in %f", interval);
    return interval;
}

int msg_xseti(s, c, name, group, val, timeout)
	MsgServer	 s;
	Client		 c;
	char		*name;
	int		 group;
	int		 val;
	double		 timeout;
{
    return msg_quemsg(s, c
		, MsgNulType, NULL, 0
		, group, timeout, "set %s %d", name, val);
}

int msg_xsetf(s, c, name, group, val, timeout)
	MsgServer	 s;
	Client		 c;
	char		*name;
	int		 group;
	float		 val;
	double		 timeout;
{
    return msg_quemsg(s, c
		, MsgNulType, NULL, 0
		, group, timeout, "set %s %f", name, val);
}

int msg_xsetd(s, c, name, group, val, timeout)
	MsgServer	 s;
	Client		 c;
	char		*name;
	int		 group;
	double		 val;
	double		 timeout;
{
    return msg_quemsg(s, c
		, MsgNulType, NULL, 0
		, group, timeout, "set %s %f", name, val);
}

int msg_xsetstr(s, c, name, group, val, timeout)
        MsgServer        s;
	Client		 c;
        char            *name;
        int              group;
        char            *val;
        double           timeout;
{
    return msg_quemsg(s, c
		, MsgNulType, NULL, 0
		, group, timeout, "set %s %s", name, val);
}

int msg_xsetblk(s, c, name, group, val, leng, timeout)
        MsgServer        s; 
	Client		 c;
        char            *name;
        int              group;
        void            *val;
	int		 leng;
        double           timeout;
{
    return msg_quemsg(s, c
		, MsgBlkWrit, val, leng
		, group, timeout, "set %s %d", name, leng);
}


static int MsgId = 0;

int msg_nextid() {

    #ifdef _REENTRANT
        static pthread_mutex_t  Global_mutex=PTHREAD_MUTEX_INITIALIZER;
        pthread_mutex_lock(&Global_mutex);
    #endif

	MsgId += 2;

    #ifdef _REENTRANT
        pthread_mutex_unlock(&Global_mutex);
    #endif
    return MsgId;
}

#ifdef __STDC__
msg_quemsg(
	  MsgServer s
	, Client    c
	, int type
	, void *data
	, int leng
	, int group
	, double timeout
	, char *command, ...)
{
        va_list         args;

	File	f;
	int	ret;
	int	msgid;

    va_start(args, command);
#else
msg_quemsg(va_alist) va_dcl
{
    va_list         args;
 
	MsgServer s;
	Client	  c;
	int type;
	void *data;
	int leng;
	int group;
	double timeout;
	char *command;

	File	f;
	int	ret;
	int	msgid;


    va_start(args);
        s     	= va_arg(args, MsgServer);
	c	= va_arg(args, Client);
	type	= va_arg(args, int);
	data	= va_arg(args, void *);
	leng	= va_arg(args, int);
	group	= va_arg(args, int);
	timeout	= va_arg(args, double);
	command	= va_arg(args, char *);
#endif
	msgid = group ? msg_nextid() + s->msgid : 0;

  do {
    if ( c->type != MsgServerSide && s->up == 0 ) {
	if ( (int) msg_reopen(s) )
	    return msg_error(s, MsgErrSrvDown, "msg: server down");
	else
    	    f = s->clnts[0].out;
    } else
	f = c->out;

    msg_logline(c, msgid, NULL, command, args);

    if ( msgid )
     fprintf(f, "%u ", msgid);
    vfprintf(f, command, args);
     fprintf(f, "\n");

    if ( type == MsgBlkWrit ) {
	Write(f, data, leng, 1);
	Flush(f);
	type = MsgNulType;
	data = NULL;
	leng = 0;
    }

    Flush(f);

    if ( Flush(f) == EOF ) {
	s->up = 0;
	ret   = MsgErrKilClnt;
    } else {
	ret =  msg_syncs(s, group, msgid, type, data, leng, timeout);
    }
  } while ( ret == MsgErrKilClnt );

  if ( group > 0 )  return msgid;
  else 		    return ret;
}


msg_logfile(s, file)
	MsgServer s;
	char *file;
{ 
    if( s->logfile != NULL )
	fclose(s->logfile);
    s->logfile=fopen(file,"a");
    if( s->logfile == NULL )
	fprintf(stderr,"Unsuccessful opening of logfile: %s\n",file);
    return;
}

msg_loginit(s, logfile)
	MsgServer s;
	char *logfile;
{
    char *getenv();
    char *fptr;
    fptr=NULL;
    if( logfile == NULL ) {
      if (  (fptr = getenv("MSGLOG")) == NULL ) 
    	s->logfile=NULL; 
      else
	msg_logfile(s,fptr);
    } else {
	msg_logfile(s,logfile);
	fptr=logfile;
    }
    return;
}


msg_logline(c, msgid, cmd, format, args)
	Client  c;
	int	   msgid;
	char	  *cmd;
	char	  *format;
	va_list	   args;
{
    if ( msg_debug  ) {
        msg_logline0(stderr,     c, msgid, cmd, format, args);
    }

    if ( c->server->logfile )
	msg_logline0(c->server->logfile, c, msgid, cmd, format, args);
}

msg_logline0(file, c, msgid, cmd, format, args)
	File	   file;
	Client     c;
	int	   msgid;
	char	  *cmd;
	char	  *format;
	va_list	   args;
{ 
	MsgServer	s = c->server;

	char 	*ctime();
	time_t   clock;
	char 	 xtime[30];

    if ( !file ) return;

    clock = time(NULL);
    strcpy(xtime, ctime(&clock));
    xtime[24] = '\0';

    fprintf(file, "%s\t%s\t%s\t%s\t%d\t", xtime, s->name, s->sok
		, c->type == MsgServerSide ? "<" : ">", c->inp ? FileFd(c->inp) : -1 );

    if ( msgid ) fprintf(file, "%u ", msgid);
    if ( cmd   ) fprintf(file, "%s ", cmd);
    if ( format ) vfprintf(file, format, args);
    fprintf(file, "\n");
    Flush(file);
}

/* log a message */
int msg_dbg(MsgServer s, char *format, ...)
{
    va_list         args;
    va_start(args, format);

    msg_logline(&s->clnts[0], 0, NULL, format, args);
}

