
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/uio.h>

#include <netinet/in.h>
#include <netdb.h>

#include <xos.h>
#include <xfile.h>
#include "msg.h"

#include <fcntl.h>


typedef struct MsgCastHead {
    int		msgid;
    int		count;
    int		off;
    int		len;
} *MsgCastHead;

#define MSG_MutliCastBlockSize	     (1480 * 10 - sizeof(struct MsgCastHead))


int msg_bussync(m, nth)
    MsgServer	m;
    int		nth;
{
    MsgValue bus = &m->values[nth - 1];

    if ( !bus->range ) {
	fprintf(stderr, "sync without range!\n");
    }
 
    bus->range = range_union(bus->range);

    if ( NRange(bus->range) != 1 ) {
	fprintf(stderr, "sync with disjoint range!\n");
	range_print(stderr, bus->range);
	return 0;
    }
    msg_clntcmd(m, -nth, MsgNulType, NULL, 0, MsgNoAck, 0.0
	    , "%s %d %d %d"
	    , bus->name
	    , bus->msgid
	    , NthRange(bus->range, 0).start
	    , NthRange(bus->range, 0).end);

    Free(bus->range);
    bus->msgid++;
    bus->count = 0;
    return 1;
}


int msg_buspost(m, nth, data, offset, length)
    MsgServer	 m;
    int		 nth;
    char	*data;
    int		 offset;
    int		 length;
{
    MsgValue    bus   = &m->values[nth - 1];

    struct MsgCastHead head;
    struct msghdr       msg;
    struct iovec        iov[2];

    int	left;

    memset(&msg, 0, sizeof(msg));

    bus->range = range_add(bus->range, offset, offset+length);

    head.msgid	       = htonl(bus->msgid);
    head.count	       = htonl(bus->count);

    msg.msg_name       = (struct sockaddr *) SokAddr(bus->file);
    msg.msg_namelen    = sizeof(struct sockaddr_in);
    msg.msg_iov        = iov;
    msg.msg_iovlen     = 2;

    iov[0].iov_base = (void *) &head;
    iov[0].iov_len  =  sizeof(struct MsgCastHead);

    for ( left = length
	; left
 	; left -= iov[1].iov_len
 		, data    += iov[1].iov_len
 		, offset  += iov[1].iov_len ) {
	iov[1].iov_base = data;
	iov[1].iov_len  = left > MSG_MutliCastBlockSize
	    	? MSG_MutliCastBlockSize : left;

	head.off   = htonl(offset);
	head.len   = htonl(iov[1].iov_len);
        head.count = htonl(bus->count);

    	if ( sendmsg(FileFd(bus->file), &msg, 0) < 0 ) {
	    perror("msg_buspost");
	    return 0;
	}

	bus->count++;
    }

    return 1;
}

void MsgCastServerCmd(m, c, msgid, data, argc, argv)
    MsgServer        m;
    Client           c;
    int              msgid;
    char            *data;
    int              argc;
    char            *argv[];
{
    MsgValue bus = (MsgValue) data;

    /* Call server callback to get data address */
    /* Re post bus */
    /* Re sync bus */
}

MsgCastPublish(m, nth)
    MsgServer	m;
    int		nth;
{
    MsgValue bus = &m->values[nth];
    char    *sok;

    if (  (sok = (char *) getenv(bus->name)) == NULL ) {
	return 0;
    }

    bus->msgid = 0;
    bus->range = NULL;
    bus->msgid = 1;
    bus->count = 0;
    if ( !(bus->file  = (File) SokMult(sok, 0, XFCREAT | XFREAD)) ) {
	return 0;
    }
    msg_register(m, bus->name, 0, MsgCastServerCmd, bus, NULL);

    return 1;
}

MsgCastRecvData(m, file, data)
    MsgServer	 m;
    File	 file;
    void	*data;	
{
    MsgValue	bus   = data;

    struct MsgCastHead head;
    struct sockaddr_in from;
    struct msghdr       msg;
    struct iovec        iov[2];

    int		msgid;
    int		count;
    int		off;
    int		len;
    int		i;


    if ( !file ) return;

    from = *((struct sockaddr_in *) SokAddr(bus->file));

    while ( 1 ) {
	msg.msg_name       = (struct sockaddr *) &from;
	msg.msg_namelen    = sizeof(from);
	msg.msg_iov        = iov;
	msg.msg_iovlen     = 1;

	iov[0].iov_base = (void *) &head;
	iov[0].iov_len  =  sizeof(struct MsgCastHead);

	if ( recvmsg(FileFd(file), &msg, MSG_PEEK) < 0 ) {
	    break;
	}

	count = ntohl(head.count);
	msgid = ntohl(head.msgid);

	if ( bus->range && !count ) {
	    Free(bus->range);
	}

	if ( !bus->range && count 
	  ||  bus->msgid >  msgid ) {
	    msg.msg_name    = (struct sockaddr *) &from;
	    recvmsg(FileFd(file), &msg, 0);
	    continue;
	}

	msg.msg_name    = (struct sockaddr *) &from;
	msg.msg_namelen = sizeof(from);
	msg.msg_iovlen  = 2;

	off = ntohl(head.off);
	len = ntohl(head.len);

	iov[1].iov_base = (char *) bus->data + off;
	iov[1].iov_len  = len;

	recvmsg(FileFd(file), &msg, 0);
	if ( !bus->range ) {
	    bus->msgid = msgid;
	}
        bus->range = range_add(bus->range, off, off + len);
    }
}

void MsgCastClientCmd(m, c, msgid, bus, argc, argv)
    MsgServer        m;
    Client           c;
    int              msgid;
    MsgValue         bus;
    int              argc;
    char            *argv[];
{
    int	start;
    int	end;

    if ( argc != 4 ) {
	fprintf(stderr, "multicast sync message error: wrong number of args\n");
	return;
    }

    start = atoi(argv[2]);
    end   = atoi(argv[3]);


    if ( !bus->range ) {
	fprintf(stderr, "sync without range!\n");
	return;
    }
    bus->range = range_union(bus->range);

    if ( NRange(bus->range) != 1
      || NthRange(bus->range, 0).start != start
      || NthRange(bus->range, 0).end   != end) {
	fprintf(stderr, "multicast sync message error: range mismatch\n");
	fprintf(stderr, "multicast expecting range start = %d end = %d\n"
		, start, end);
	fprintf(stderr, "multicast recieved:\n");
	range_print(stderr, bus->range);
        Free(bus->range);

	return;
    }

    Free(bus->range);
    (*bus->func)(m, MsgSetVal, bus->name, bus->data, (char *) bus->buff+ start, end - start);
}

MsgCastConnect(m, bus)
    MsgServer	m;
    MsgValue bus;
{
    char    *sok;
    bus->range = NULL;

    if (  (sok = (char *) getenv(bus->name)) == NULL ) {
	return 0;
    }
    
    if ( !(bus->file = (File) SokMult(sok, 0, XFREAD | XFWRITE)) ) {
	perror("msg multi");
    }
    fcntl(FileFd(bus->file), F_SETFL, O_NONBLOCK);

    bus->count = 0;
    bus->msgid = 0;

    msg_addinput(m, bus->file, MsgCastRecvData, bus, 0);
}

MsgCastSubscribe(m, nth) 
    MsgServer	m;
    int		nth;
{
    MsgValue bus = &m->values[nth];

    msg_register(m, bus->name, 0, MsgCastClientCmd, bus, NULL);

    if ( m->up ) MsgCastConnect(m, bus);
}

