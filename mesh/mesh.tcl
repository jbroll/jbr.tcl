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
