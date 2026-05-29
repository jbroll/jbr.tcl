# mesh.tcl — jbr::mesh: Meshtastic StreamAPI serial interface
package require critcl 3.1
package provide jbr::mesh 1.0

critcl::clibraries -L/home/john/lib -ltclstub

namespace eval mesh {
    variable fd       ""
    variable state    SYNC1
    variable buf      ""
    variable need     0
    variable callback ""
}

critcl::ccode {
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <tcl.h>

/* ---- minimal protobuf encode helpers ---- */

#define PB_VARINT 0
#define PB_32BIT  5
#define PB_LEN    2
#define PB_TAG(fn, wt) (((fn) << 3) | (wt))

static int pb_varint(uint8_t *buf, uint64_t v) {
    int n = 0;
    while (v > 0x7f) { buf[n++] = (uint8_t)((v & 0x7f) | 0x80); v >>= 7; }
    buf[n++] = (uint8_t)v;
    return n;
}

/* write tag + varint value; returns bytes written */
static int pb_field_varint(uint8_t *buf, int fn, uint64_t v) {
    int n = pb_varint(buf, PB_TAG(fn, PB_VARINT));
    n += pb_varint(buf + n, v);
    return n;
}

/* write tag + length-delimited bytes; returns bytes written */
static int pb_field_len(uint8_t *buf, int fn, const uint8_t *data, int len) {
    int n = pb_varint(buf, PB_TAG(fn, PB_LEN));
    n += pb_varint(buf + n, (uint64_t)len);
    memcpy(buf + n, data, len);
    return n + len;
}

/* encode Data { portnum, payload } -> buf; returns bytes written */
static int encode_data(uint8_t *buf, int portnum,
                       const uint8_t *payload, int payload_len) {
    int n = 0;
    n += pb_field_varint(buf + n, 1, (uint64_t)portnum);
    n += pb_field_len   (buf + n, 2, payload, payload_len);
    return n;
}

/* encode MeshPacket { to, decoded:Data } -> buf; returns bytes written */
static int encode_meshpacket(uint8_t *buf, uint32_t to_node,
                             int portnum,
                             const uint8_t *payload, int payload_len) {
    uint8_t data_buf[2048];
    int data_len = encode_data(data_buf, portnum, payload, payload_len);
    int n = 0;
    n += pb_field_varint(buf + n, 3, (uint64_t)to_node);
    n += pb_field_len   (buf + n, 4, data_buf, data_len);
    return n;
}

/* encode ToRadio { packet:MeshPacket } -> buf; returns bytes written */
static int encode_toradio(uint8_t *buf, uint32_t to_node,
                          int portnum,
                          const uint8_t *payload, int payload_len) {
    uint8_t mp_buf[2100];
    int mp_len = encode_meshpacket(mp_buf, to_node, portnum, payload, payload_len);
    return pb_field_len(buf, 1, mp_buf, mp_len);
}
}

# mesh::encode_packet to_node port_num payload_bytes
# Returns a binary Tcl value: the StreamAPI-framed ToRadio protobuf
critcl::cproc mesh::encode_packet {
    Tcl_Interp* interp
    unsigned    to_node
    int         port_num
    Tcl_Obj*    payload_obj
} Tcl_Obj* {
    Tcl_Size pay_len;
    const uint8_t *pay = Tcl_GetByteArrayFromObj(payload_obj, &pay_len);

    uint8_t pb_buf[4096];
    int pb_len = encode_toradio(pb_buf, (uint32_t)to_node, port_num,
                                pay, (int)pay_len);

    /* StreamAPI frame: 0x94 0xc3 len_hi len_lo payload */
    uint8_t frame[4 + 4096];
    frame[0] = 0x94;
    frame[1] = 0xc3;
    frame[2] = (uint8_t)((pb_len >> 8) & 0xff);
    frame[3] = (uint8_t)(pb_len & 0xff);
    memcpy(frame + 4, pb_buf, pb_len);

    return Tcl_NewByteArrayObj(frame, 4 + pb_len);
}
