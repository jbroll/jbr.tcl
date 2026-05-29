# mesh.tcl — jbr::mesh: Meshtastic StreamAPI serial interface
package require critcl 3.1
package provide jbr::mesh 1.0

critcl::tcl 8.6

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

/* ---- minimal protobuf decode helpers ---- */

/* read varint from buf[off..len-1]; advance *off; return 0 on truncation */
static int pb_read_varint(const uint8_t *buf, int len, int *off, uint64_t *out) {
    *out = 0;
    int shift = 0;
    while (*off < len) {
        uint8_t b = buf[(*off)++];
        *out |= (uint64_t)(b & 0x7f) << shift;
        shift += 7;
        if (!(b & 0x80)) return 1;
    }
    return 0; /* truncated */
}

/* skip one field value given its wire type; return 0 on error */
static int pb_skip(const uint8_t *buf, int len, int *off, int wt) {
    uint64_t v;
    switch (wt) {
        case PB_VARINT:
            return pb_read_varint(buf, len, off, &v);
        case PB_LEN:
            if (!pb_read_varint(buf, len, off, &v)) return 0;
            *off += (int)v;
            return (*off <= len);
        case PB_32BIT:
            *off += 4;
            return (*off <= len);
        default:
            return 0;
    }
}

typedef struct {
    uint32_t from_node;
    uint32_t to_node;
    int      portnum;
    int      payload_off;   /* byte offset into the original frame buffer */
    int      payload_len;
    float    rx_snr;
    int32_t  rx_rssi;
} MeshFields;

/* parse Data { portnum, payload } from buf[0..len-1]; fill m
   payload_off is relative to buf */
static void decode_data(const uint8_t *buf, int len, MeshFields *m) {
    int off = 0;
    while (off < len) {
        uint64_t tag;
        if (!pb_read_varint(buf, len, &off, &tag)) break;
        int fn = (int)(tag >> 3);
        int wt = (int)(tag & 7);
        if (fn == 1 && wt == PB_VARINT) {
            uint64_t v;
            if (pb_read_varint(buf, len, &off, &v)) m->portnum = (int)v;
        } else if (fn == 2 && wt == PB_LEN) {
            uint64_t v;
            if (pb_read_varint(buf, len, &off, &v)) {
                m->payload_off = off;
                m->payload_len = (int)v;
                off += m->payload_len;
            }
        } else {
            if (!pb_skip(buf, len, &off, wt)) break;
        }
    }
}

/* parse MeshPacket from buf[start..start+len-1]; fill m
   payload_off in m is set relative to buf (absolute within the frame) */
static void decode_meshpacket(const uint8_t *buf, int start, int len, MeshFields *m) {
    int off = start;
    int end = start + len;
    while (off < end) {
        uint64_t tag;
        if (!pb_read_varint(buf, end, &off, &tag)) break;
        int fn = (int)(tag >> 3);
        int wt = (int)(tag & 7);
        if (fn == 1 && wt == PB_VARINT) {
            uint64_t v; if (pb_read_varint(buf, end, &off, &v)) m->from_node = (uint32_t)v;
        } else if (fn == 3 && wt == PB_VARINT) {
            uint64_t v; if (pb_read_varint(buf, end, &off, &v)) m->to_node   = (uint32_t)v;
        } else if (fn == 4 && wt == PB_LEN) {
            uint64_t v;
            if (pb_read_varint(buf, end, &off, &v)) {
                /* decode_data sets payload_off relative to (buf+off);
                   we adjust below to make it relative to buf */
                int data_start = off;
                decode_data(buf + off, (int)v, m);
                m->payload_off += data_start;  /* adjust to global buf offset */
                off += (int)v;
            }
        } else if (fn == 8 && wt == PB_32BIT) {
            if (off + 4 <= end) {
                memcpy(&m->rx_snr, buf + off, 4);
                off += 4;
            }
        } else if (fn == 14 && wt == PB_VARINT) {
            uint64_t v; if (pb_read_varint(buf, end, &off, &v)) m->rx_rssi = (int32_t)v;
        } else {
            if (!pb_skip(buf, end, &off, wt)) break;
        }
    }
}
}

# mesh::decode_frame raw_protobuf_bytes
# raw_protobuf_bytes is the protobuf payload WITHOUT the StreamAPI header.
# Returns a dict: portnum from to payload rssi snr
# portnum=0 and empty payload indicates a non-packet FromRadio (e.g. config).
critcl::cproc mesh::decode_frame {
    Tcl_Interp* interp
    Tcl_Obj*    frame_obj
} Tcl_Obj* {
    int frame_len = 0;
    const uint8_t *buf = (const uint8_t *)Tcl_GetByteArrayFromObj(frame_obj, &frame_len);
    if (!buf) return NULL;

    MeshFields m;
    memset(&m, 0, sizeof(m));
    m.payload_off = -1;

    /* parse FromRadio; look only for field 2 (packet, LEN) */
    int off = 0;
    while (off < (int)frame_len) {
        uint64_t tag;
        if (!pb_read_varint(buf, (int)frame_len, &off, &tag)) break;
        int fn = (int)(tag >> 3);
        int wt = (int)(tag & 7);
        if (fn == 2 && wt == PB_LEN) {
            uint64_t v;
            if (pb_read_varint(buf, (int)frame_len, &off, &v)) {
                decode_meshpacket(buf, off, (int)v, &m);
                off += (int)v;
            }
        } else {
            if (!pb_skip(buf, (int)frame_len, &off, wt)) break;
        }
    }

    Tcl_Obj *dict = Tcl_NewDictObj();
    Tcl_DictObjPut(interp, dict,
        Tcl_NewStringObj("portnum", -1), Tcl_NewIntObj(m.portnum));
    Tcl_DictObjPut(interp, dict,
        Tcl_NewStringObj("from", -1),
        Tcl_NewWideIntObj((Tcl_WideInt)(uint64_t)m.from_node));
    Tcl_DictObjPut(interp, dict,
        Tcl_NewStringObj("to",   -1),
        Tcl_NewWideIntObj((Tcl_WideInt)(uint64_t)m.to_node));
    Tcl_DictObjPut(interp, dict,
        Tcl_NewStringObj("rssi", -1), Tcl_NewIntObj(m.rx_rssi));
    Tcl_DictObjPut(interp, dict,
        Tcl_NewStringObj("snr",  -1), Tcl_NewDoubleObj((double)m.rx_snr));

    if (m.payload_off >= 0 &&
        m.payload_off + m.payload_len <= (int)frame_len) {
        Tcl_DictObjPut(interp, dict,
            Tcl_NewStringObj("payload", -1),
            Tcl_NewByteArrayObj(buf + m.payload_off, m.payload_len));
    } else {
        Tcl_DictObjPut(interp, dict,
            Tcl_NewStringObj("payload", -1),
            Tcl_NewByteArrayObj(NULL, 0));
    }

    Tcl_IncrRefCount(dict);
    return dict;
}

# mesh::encode_packet to_node port_num payload_bytes
# Returns a binary Tcl value: the StreamAPI-framed ToRadio protobuf
critcl::cproc mesh::encode_packet {
    Tcl_Interp* interp
    long        to_node
    int         port_num
    Tcl_Obj*    payload_obj
} Tcl_Obj* {
    int pay_len = 0;
    const uint8_t *pay = (const uint8_t *)Tcl_GetByteArrayFromObj(payload_obj, &pay_len);
    if (!pay) return NULL;
    if (pay_len > 220) {
        Tcl_SetResult(interp, "mesh: payload exceeds 220-byte LoRa MTU limit", TCL_STATIC);
        return NULL;
    }

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

    Tcl_Obj *result = Tcl_NewByteArrayObj(frame, 4 + pb_len);
    Tcl_IncrRefCount(result);
    return result;
}

# ---- Tcl layer: serial I/O, StreamAPI framing, public API ----

proc mesh::_on_readable {} {
    variable fd
    variable state
    variable buf
    variable need
    variable callback

    set data [read $fd]
    if {[eof $fd]} {
        catch {fileevent $fd readable {}}
        catch {::close $fd}
        set fd ""
        if {$callback ne ""} { {*}$callback {event disconnect} }
        return
    }

    append buf $data

    while 1 {
        switch $state {
            SYNC1 {
                # scan for 0x94
                set pos [string first "\x94" $buf]
                if {$pos < 0} { set buf ""; return }
                set buf [string range $buf $pos end]
                set state SYNC2
            }
            SYNC2 {
                if {[string length $buf] < 2} return
                if {[string index $buf 1] eq "\xc3"} {
                    set buf [string range $buf 2 end]
                    set state LEN
                } else {
                    # not 0xc3 — discard 0x94, keep scanning
                    set buf [string range $buf 1 end]
                    set state SYNC1
                }
            }
            LEN {
                if {[string length $buf] < 2} return
                binary scan $buf Su need
                set buf [string range $buf 2 end]
                set state DATA
            }
            DATA {
                if {[string length $buf] < $need} return
                set frame [string range $buf 0 [expr {$need - 1}]]
                set buf   [string range $buf $need end]
                set state SYNC1
                if {$callback ne "" && [string length $frame] > 0} {
                    set pkt [mesh::decode_frame $frame]
                    {*}$callback $pkt
                }
            }
        }
    }
}

proc mesh::open {device {cb ""}} {
    variable fd
    variable state
    variable buf
    variable callback

    set fd [::open $device r+]
    fconfigure $fd \
        -mode 115200,n,8,1 \
        -translation binary \
        -buffering full \
        -blocking 0
    set state    SYNC1
    set buf      ""
    set callback $cb
    fileevent $fd readable mesh::_on_readable
}

proc mesh::close {} {
    variable fd
    if {$fd ne ""} {
        catch {fileevent $fd readable {}}
        catch {::close $fd}
        set fd ""
    }
}

proc mesh::on_receive {script} {
    variable callback
    set callback $script
}

proc mesh::send_text {to_node text} {
    variable fd
    set bytes [encoding convertto utf-8 $text]
    set frame [mesh::encode_packet $to_node 1 $bytes]
    puts -nonewline $fd $frame
    flush $fd
}

proc mesh::send_data {to_node portnum bytes} {
    variable fd
    set frame [mesh::encode_packet $to_node $portnum $bytes]
    puts -nonewline $fd $frame
    flush $fd
}
