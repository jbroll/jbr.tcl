/* msg.h
 */
#ifndef __MSG_H
#define __MSG_H

#include <xos.h>
#include <xfile.h>
#include <range.h>


#define MsgErrLen       256

extern int	msg_debug;
extern char	msg_errstr[MsgErrLen];

#define MsgServerTick	  0.200

#define MsgWait		 -1
#define MsgNoAck	  0

#define MsgBufferSize   512
#define MsgMaxArgs       64
#define MsgMaxClients	128

#define MsgServerSide	444
#define MsgClientSide	333
#define MsgAddInpType	222

#define MsgIntType	'i'
#define MsgFltType	'f'
#define MsgDblType	'd'
#define MsgStrType	's'
#define MsgBlkWrit	'X'
#define MsgBlkType	'x'
#define MsgNulType	'n'
#define MsgBusType	'b'
#define MsgCmdType	'n'

#define MsgGetVal	'g'
#define MsgSetVal	's'
#define MsgLokVal	'l'

#define MsgAck		  1
#define MsgWaiting	  0 
#define MsgNak		 -1
#define MsgErrBuffout	 -2
#define MsgErrTimeout	 -3
#define MsgErrNoAsync	 -4
#define MsgErrKilClnt	 -5
#define MsgErrSrvDown	 -6
#define MsgErrSelect	 -7


#define MsgPostCache	0
#define MsgPostMark	1
#define MsgPostNow	2

#define MsgNoParseArgs	0x0100
#define MsgNArgs	0x0200

#define MsgNTimers	10

#define msg_print	fprintf

typedef void  *(*MsgValueFunc)();
typedef int    (*MsgInputFunc)();
typedef double (*MsgTimerFunc)();

#define MsgClient(s, i)	( &s->clnts[i] )

typedef struct MsgAddInput {
    MsgInputFunc func;
    void	*data;
} *MsgAddInput;

typedef struct Async {		/* list of outstanding Async messages	*/
	int		 type;
	void		*buff;
	int		 leng;

	int		 group;
	unsigned int	 msgid;
	int		 status;
	double		 timeout;
	char		 error[MsgErrLen];
} *Async;

typedef struct Client {		/* list of clients on a server		*/
	struct MsgServer *server;
	int		  type;
	File		  inp;
	File		  out;
	char		 *address;
	char		 *tag;
	void		 *data;
} *Client;

typedef struct Subsc {
	double	interval;
	double	timeout;	/* type/ timeout of a subscription	*/
	Client	client;		/* pointer to client that is subscribed	*/
	int	pending;
} *Subsc;

typedef struct MsgValue {
	int		 type;	/* data type				*/
	void		*buff;
	void		*cach;
	int		 leng;	/* data leng				*/

	char		*name;	/* value name				*/
	MsgValueFunc	 func;	/* value method function		*/
	void		*data;
	int		nsubs;	/* number of subscription slots		*/
	Subsc		 subs;	/* Unsorted array of client subscriptions
				   NULL indicates an empty slot.	*/
	char		*comm;
	double		 time;

	int		 posted;

	/* These are used for multicast data */
	File		 file;
	Range		*range;
	int		 msgid;
	int		 count;
} *MsgValue;

typedef struct Key {
	char		*name;
	int		 leng;
	int		 flag;
	void	       (*func)();
	void		*data;
	char		*comm;
} *Key;

typedef struct Timer {
	MsgTimerFunc	func;
	void		*data;
	double		 interval;
	double		 timeout;
	int		 lock;
	int		 tid;
} *Timer;

typedef struct MsgServer {
	char		*name;
	char		*sok;
	unsigned int	 msgid;
	int		 up;
	int		(*state)();
	void		 *sdata;
	unsigned int	 clock;

	void	       *(*newclient)();
	void		 *newdata;

	void		(*kilclient)();
	void		 *kildata;

	void		(*error)();
	void		 *errdata;

	struct Client	 clnts[MsgMaxClients];

	int		 mapfd[1024];
	int		 maxfd;
	fd_set		 rfds;

	FILE		 *logfile;
	int		  log;
	int		nvalues;	/* number of values			*/
	int		avalues;	/* number of value slots allocated	*/
	MsgValue	values;		/* sorted array of pointers to values	*/
	int		nkeys;		/* number of protocal keys		*/
	int		akeys;		/* number of protocal keys		*/
	Key		 keys;		/* command pattern action structures	*/
	int		nasyncs;	/* async buffers			*/
	Async		 asyncs;
	struct Timer	 timers[MsgNTimers];	/* timer buffers			*/

	int		tid;
} *MsgServer;



#define msg_clntofp(m, server)	(m->clnts[0].out)
#define msg_clntifp(m, server)	(m->clnts[0].in)
#define msg_servofp(m, server)	(m->clnts[0].out)
#define msg_servifp(m, server)	(m->clnts[0].in)


/* msg.c */

int msg_register PROTOTYPE((MsgServer s, char *key, int flag, void (*func)(), void *data, char *comment));
int msg_newclient PROTOTYPE((MsgServer s));
int msg_kilclient PROTOTYPE((MsgServer s, Client c));
int msg_handler PROTOTYPE((MsgServer s, Client c));
int msg_waitloop PROTOTYPE((MsgServer *s, int n, int group, int msgid, double timeout));
int msg_addinput PROTOTYPE((MsgServer s, File input, MsgInputFunc func, void *data, int mode));
int msg_addtimer PROTOTYPE((MsgServer s, double interval, MsgTimerFunc func, void *data));
void msg_loop PROTOTYPE((MsgServer s));
int msg_wdata PROTOTYPE((File f, void *pointer, int size));
int msg_rdata PROTOTYPE((File f, void *pointer, int size));
int msg_syncs PROTOTYPE((MsgServer s, int group, int msgid, int type, void *valptr, int leng, double timeout));
int msg_addasync PROTOTYPE((MsgServer s, int group, int msgid, int type, void *valptr, int leng, double timeout));
int msg_dbg PROTOTYPE((MsgServer c, char *format, ...));
void msg_log PROTOTYPE((MsgServer s, Client c, char *type, char *line));
int msg_ack PROTOTYPE((Client c, int msgid, char *err, ...));
int msg_nak PROTOTYPE((Client c, int msgid, char *err, ...));
Async msg_lookupasync PROTOTYPE((MsgServer s, int msgid));
MsgValue msg_lookupval PROTOTYPE((MsgServer s, char *name));


void imsg_hup();
void imsg_ack();
void imsg_nak();
void imsg_set();
void imsg_log();

int 	 MsgAddValue PROTOTYPE((MsgServer s, char *name, int type, void *buff, int leng, void *(*func)(), void *data, char *comment, double timer));
Key 	 msg_parse PROTOTYPE((MsgServer s, char *line, int *msgid, int *argc, char *argv[]));
int 	 MsgAddSubsc PROTOTYPE((MsgValue v, Client client, double timeout));
Subsc	 MsgLookupSubsc PROTOTYPE((MsgValue v, Client c, int *i));
Async	 MsgNextAsync PROTOTYPE((MsgServer s));



/* clnt.c */
MsgServer msg_client PROTOTYPE((char *, int (*state)(), void *data, char *tag));
MsgServer msg_open PROTOTYPE((char *, int (*state)(), void *data));
int msg_command PROTOTYPE((
	  MsgServer s
	, int type
	, void *data
	, int leng
	, int group
	, double timeout
	, char *command, ...));
int msg_quemsg PROTOTYPE((
	  MsgServer s
	, Client    c
	, int type
	, void *data
	, int leng
	, int group
	, double timeout
	, char *command, ...));
int msg_subscribe PROTOTYPE((MsgServer s, char *name, int type, void *buff, int leng, double timer, MsgValueFunc func, void *data, double timeout, ...));
int msg_unsubscribe PROTOTYPE((MsgServer s, char *name, int timeout));
int msg_list PROTOTYPE((MsgServer s));

int msg_xseti PROTOTYPE((MsgServer s, Client c, char *name, int group, int val, double timeout));
int msg_xsetd PROTOTYPE((MsgServer s, Client c, char *name, int group, double val, double timeout));
int msg_xsetstr PROTOTYPE((MsgServer s, Client c, char *name, int group, char *val, double timeout));
int msg_xsetblk PROTOTYPE((MsgServer s, Client c, char *name, int group, void *val, int leng, double timeout));
int msg_ageti PROTOTYPE((MsgServer s, char *name, int group, int *valptr, double timeout));
int msg_agetd PROTOTYPE((MsgServer s, char *name, int group, double *valptr, double timeout));
int msg_agetstr PROTOTYPE((MsgServer s, char *name, int group, char *valptr, int max, double timeout));

int msg_agetblk PROTOTYPE((MsgServer s, char *name, int group, void *valptr, int leng, double timeout));



int msg_seti PROTOTYPE((MsgServer s, char *name, int val, double timeout));
int msg_setd PROTOTYPE((MsgServer s, char *name, double val, double timeout));
int msg_setf PROTOTYPE((MsgServer s, char *name, double val, double timeout));
int msg_setstr PROTOTYPE((MsgServer s, char *name, char *val, double timeout));
int msg_setblk PROTOTYPE((MsgServer s, char *name, void *val, int leng, double timeout));

int msg_geti PROTOTYPE((MsgServer s, char *name, int *val, double timeout));
int msg_getd PROTOTYPE((MsgServer s, char *name, double *val, double timeout));
int msg_getf PROTOTYPE((MsgServer s, char *name, float *val, double timeout));
int msg_getstr PROTOTYPE((MsgServer s, char *name, char *val, int leng, double timeout));
int msg_getblk PROTOTYPE((MsgServer s, char *name, void *val, int leng, double timeout));

/* serv.c */
MsgServer msg_server PROTOTYPE((char *server));
int msg_publish PROTOTYPE((MsgServer s, char *name, int type, void *buff, int leng, MsgValueFunc func, void *data, char *comment, ...));
int msg_xpost PROTOTYPE((MsgServer s, char *name, int type, void *valptr, int group, double timeout));

void *msg_RO PROTOTYPE((MsgServer s, int op, char *name, void *data, void *buff, int *leng));

double msg_clock();
char *msg_date(char *date);
void msg_up PROTOTYPE((MsgServer s, char *name));


#endif
