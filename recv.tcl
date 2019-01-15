
package require critcl
package provide recv 1.0

critcl::ccode {
    #include <tcl.h>
}

critcl::cproc recv { Tcl_Interp* interp char* sock } ok {
    char	bytes[1500];

    int	mode;
    int	fd;
    int	n;

    Tcl_GetChannelHandle(Tcl_GetChannel(interp, sock, &mode), TCL_READABLE, &fd);

    if ( (n = recv(fd, bytes, 1500, 0)) < 0 ) {
	return TCL_ERROR;
    }

    Tcl_SetByteArrayObj(Tcl_GetObjResult(interp), (void *) bytes, n);

    return TCL_OK;
}
