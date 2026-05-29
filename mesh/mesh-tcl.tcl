# mesh-tcl.tcl — pure Tcl layer for jbr::mesh
# Included via critcl::tsources — bundled into the package at build time.

namespace eval mesh {
    variable fd       ""
    variable state    SYNC1
    variable buf      ""
    variable need     0
    variable callback ""
}

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

# Resolve a Meshtastic serial device, resilient to /dev/ttyACMx renumbering.
# Prefers the stable /dev/serial/by-id symlink (embeds the node's USB serial),
# falling back to a ttyACM*/ttyUSB* glob. Returns "" if nothing is found.
# If $hint names an existing path, it is used as-is.
proc mesh::find_device { {hint ""} } {
    if { $hint ne "" && [file exists $hint] } { return $hint }
    foreach pat {
        /dev/serial/by-id/*heltec*
        /dev/serial/by-id/*Heltec*
        /dev/serial/by-id/*Espressif*
        /dev/ttyACM*
        /dev/ttyUSB*
    } {
        set found [lsort [glob -nocomplain $pat]]
        if { [llength $found] > 0 } { return [lindex $found 0] }
    }
    return ""
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

    # Activate the StreamAPI session. Without a want_config_id the radio will
    # neither stream received packets to us nor transmit packets we send.
    mesh::want_config
}

# Send a want_config_id ToRadio to start the serial API session.
# ToRadio { field 3 (want_config_id, varint): nonce }
proc mesh::want_config { {nonce 42} } {
    variable fd
    # Meshtastic recommends a wake preamble of 32 START2 (0xc3)... actually
    # START1 bytes so a sleeping serial console wakes before the real frame.
    set wake [string repeat \xc3 32]
    # ToRadio protobuf: tag 0x18 (field 3, varint) + varint nonce
    set proto [binary format c 0x18]
    while { $nonce > 0x7f } {
        append proto [binary format c [expr { ($nonce & 0x7f) | 0x80 }]]
        set nonce [expr { $nonce >> 7 }]
    }
    append proto [binary format c $nonce]
    set n [string length $proto]
    set frame [binary format ccS 0x94 0xc3 $n]
    append frame $proto
    puts -nonewline $fd $wake$frame
    flush $fd
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
