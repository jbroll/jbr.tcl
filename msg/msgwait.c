/* msgwait.c
 */

#include <xos.h>
#include <xfile.h>
#include <sys/time.h>

#include "msg.h"

char  *cal();
double mjd();

/* #msg_loop processes cleint requests for the server and never returns.
 */
void msg_loop(s)
	MsgServer	s;
{
	msg_waitloop(&s, 1, 0, 0, -1.0);
}

char *msg_date(char *buff) {
    return cal(buff, 32, mjd("now", -1.0, 1)+TZX()/60.0/60.0/24.0, "%Y%m%d.%T");
}
double msg_clock()
{
    struct timeval date;
    struct timezone tz;
 
    gettimeofday(&date, &tz);
    return date.tv_sec + date.tv_usec / 1000000.0;
}


/* #msg_waitloop processes client until the message in msgid is processed or
   the timeout expires.
 */
int msg_waitloop(S, n, group, msgid, timeout)
	MsgServer	*S;
	int		 n;
	int		 group;
	int		 msgid;
	double		 timeout;
{
	Async	a;
	int	i, j, k, l;
	double clock;
	double thisk = 0;
	double lastk = 0;

	MsgServer	*P;
	MsgServer	 x = NULL;
	int		 p;

	int doselect = 0;


    thisk = msg_clock();

    if ( group == MsgWait ) {		/* Wait on a single reply msgid	*/
      for ( p = 0 ; p < n; p++ ) {
	MsgServer s = S[p];

	if ( s == NULL ) continue ;

	if ( (a = msg_lookupasync(s, msgid)) != NULL ) {
	    x = s;	break;
	}
      }
      if ( p == n ) {
	    return msg_error(NULL, MsgErrNoAsync
			, "msg: no async buffer for message id.");
      }
    }


    while ( 1 ) {
Again:

	/* Check for async buffer completion
	 */
	if ( group ) {
	    if ( group == MsgWait ) {

		if ( a->status != MsgWaiting ) {
		    a->group = 0;	/* Mark as free	*/
		    if ( a->status == -1 )
			msg_error(x, MsgNak, a->error);

		    return a->status;
		}
	    } else {
		/* Groups are unique across servers
		 */
		for ( p = 0 ; p < n; p++ ) {
		    MsgServer s = S[p];
		    int	  k;

		    if ( s == NULL ) continue ;

		    /* See if any messages in this group are outstanding.
		     */
		    for ( k = 0; k < s->nasyncs; k++ ) {
			if ( s->asyncs[k].group  == group 
			  && s->asyncs[k].status == 0 ) {
				goto GroupNotDone;
			}
		    }
		}
		GroupDone: {
		 int 	  status = MsgAck;

		 for ( p = 0 ; p < n; p++ ) {
		    MsgServer s = S[p];
		    int	  k;

		    if ( s == NULL ) continue ;


		    /* Mark all asyncs that have been waited as free.
		     */
		    *msg_errstr = '\0';
		    for ( k = 0; k < s->nasyncs; k++ ) {
		        if ( s->asyncs[k].group  == group ) {
			    s->asyncs[k].group = 0;
			    if ( s->asyncs[k].status < 0 ) {
			        strcpy(msg_errstr, s->asyncs[k].error);
			        status = -1;
			    }
		        }
		    }
		 }
		 return status;
		}
	    }
	}
    GroupNotDone:

	clock = msg_clock();

        for ( p = 0 ; p < n; p++ ) {
	      MsgServer s = S[p];

	    if ( s == NULL ) continue ;

	    /* Check for async buffer timeout
	     */
	    for ( k = 0; k < s->nasyncs; k++ ) {
		if ( s->asyncs[k].group && s->asyncs[k].timeout > 0 && s->asyncs[k].timeout < clock ) {
		    s->asyncs[k].status = -1;
		    strcpy(s->asyncs[k].error, "Buffer timed out");
		}
	    }
	}


HandleIO: {
	fd_set  rfds;
	fd_set  wfds;
	fd_set  xfds;
	int	maxfd = 0;

  FD_ZERO(&rfds);
  FD_ZERO(&wfds);
  FD_ZERO(&xfds);


      /* OR up the selected fds
       */
      for ( p = 0 ; p < n; p++ ) {
	  MsgServer s = S[p];
	  int k;

	  if ( s == NULL ) continue ;

	  for ( k = 0; k < (s->maxfd / (sizeof(int)*8))+1; k++ ) {
	      ((int *)&rfds)[k] |= ((int *)&s->rfds)[k];
	  }

	  maxfd = Max(maxfd, s->maxfd);
      }

  if ( doselect ) {
      if ( (l = Select(maxfd+1, &rfds, &wfds, &xfds
		    , timeout >= 0 && timeout < MsgServerTick 
		    ? 0.0 : MsgServerTick)) == -1 ) {
	    return msg_error(NULL, MsgErrSelect, "msg: select error.");
      }
  }

  for ( i = 0; i <= maxfd; i++ ) {
	for ( p = 0 ; p < n; p++ ) {
		MsgServer s = S[p];
		int	  client;

	        if ( s == NULL ) continue;
		client = s->mapfd[i];

	    if ( s->clnts[client].type == MsgAddInpType ) {
		MsgAddInput inp = (MsgAddInput) s->clnts[client].data;

		(*inp->func)(s, s->clnts[client].inp, inp->data);
		break;
	    }

	    /* Check for input in the file buffer first
	     */
	    if ( i != 0 || s->clnts[client].type != MsgServerSide ) {
	     if ( s->clnts[client].inp != NULL
	       && FileLeft(s->clnts[client].inp) ) {
		    msg_handler(s, MsgClient(s, client));
		    doselect = 0;
		    goto Again;
	     }
	    }

	    /* Then check for selected fds
	     */
	    if ( doselect && FD_ISSET(i, &s->rfds) && FD_ISSET(i, &rfds) ) {

		if ( s->clnts[client].type == MsgServerSide && client == 0 ) {
		    msg_newclient(s);
		} else {
		    msg_handler(s, &s->clnts[client]);
	 	} 

		break;
	    }
	}
  }
}

	doselect = 1;

	clock = msg_clock();
	if ( clock != S[0]->clock ) {
          for ( p = 0 ; p < n; p++ ) {
	      MsgServer s = S[p];

	      if ( s == NULL ) continue ;


	    s->clock = clock;
	    if ( s->clnts[0].type == MsgServerSide ) {
		/* Check value subscriptions
		 */
		for ( i = 0; i < s->nvalues; i++ ) {
		    int update = s->values[i].posted;
		    if (!update 
		     && s->values[i].buff != NULL 
		     && s->values[i].cach != NULL ) {
			 update = msg_cache(s->values[i].buff
				    , s->values[i].cach
				    , s->values[i].leng
				    , s->values[i].type);
		    }

		    for ( j = 0; j < s->values[i].nsubs; j++ ) {
		      if ( s->values[i].subs[j].client   != NULL ) {

			/* This subscription is post only and the value wasn't
			   posted
			 */
		 	if ( s->values[i].subs[j].interval == 0.0
			 && !s->values[i].posted ) continue;


			/* This subscription is for the client which set the 
			   value.  Skip it unless its already pending.
			 */
			if ( update != -1
			  && s->values[i].subs[j].client == &s->clnts[update]
			  && !s->values[i].subs[j].pending )
				continue;

			/* The value needs to be updated for this subscription
			 */
			if ( update ) s->values[i].subs[j].pending = 1;

		        if ( s->values[i].subs[j].timeout <= clock 
			  && s->values[i].subs[j].pending ) {


			    msg_setbytype(s->values[i].type
				    , s, s->values[i].subs[j].client
				    , s->values[i].name
				    , MsgNoAck
				    , s->values[i].cach
				    , s->values[i].leng
				    , 0.0);

			    s->values[i].subs[j].timeout =
				clock + Abs(s->values[i].subs[j].interval);

		            if ( s->values[i].subs[j].interval >= 0.0 )
				 s->values[i].subs[j].pending = 0;
			}
		      }
		    }

		    s->values[i].posted = 0;
		}

	    }
	    /* Check timer timeouts
	     */
	    for ( i = 0; i < MsgNTimers; i++ ) {
		if ( !s->timers[i].lock 
		   && s->timers[i].interval != 0.0 
		   && s->timers[i].timeout <= clock ) {
		    s->timers[i].lock = 1;
		    s->timers[i].timeout = 
			clock + (*s->timers[i].func)(s, s->timers[i].tid
						      , s->timers[i].data);
		    if ( s->timers[i].timeout == clock ) 
			s->timers[i].interval = 0.0;
		    s->timers[i].lock = 0;
		}
	    }
	  }
	}

        lastk = msg_clock();

	/* Check for wait loop timeout
	 */
	if ( timeout == 0.0 || (timeout > 0 && thisk + timeout < lastk) ) {
	    if ( !msgid && !group ) {
		return MsgErrTimeout;
	    } else {
		char buffer[100];
		sprintf(buffer,"msg: timeout: msgid: %d msgroup: %d",msgid,group);
		return msg_error(x, MsgErrTimeout, buffer);
	    }
	}
    }
}
