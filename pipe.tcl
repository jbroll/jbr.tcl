# This software is copyrighted 2013 by G. Andrew Mangogna.
# The following terms apply to all files associated with the software unless
# explicitly disclaimed in individual files.
# 
# The authors hereby grant permission to use, copy, modify, distribute,
# and license this software and its documentation for any purpose, provided
# that existing copyright notices are retained in all copies and that this
# notice is included verbatim in any distributions. No written agreement,
# license, or royalty fee is required for any of the authorized uses.
# Modifications to this software may be copyrighted by their authors and
# need not follow the licensing terms described here, provided that the
# new terms are clearly indicated on the first page of each file where
# they apply.
# 
# IN NO EVENT SHALL THE AUTHORS OR DISTRIBUTORS BE LIABLE TO ANY PARTY FOR
# DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING
# OUT OF THE USE OF THIS SOFTWARE, ITS DOCUMENTATION, OR ANY DERIVATIVES
# THEREOF, EVEN IF THE AUTHORS HAVE BEEN ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
# 
# THE AUTHORS AND DISTRIBUTORS SPECIFICALLY DISCLAIM ANY WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT.  THIS SOFTWARE
# IS PROVIDED ON AN "AS IS" BASIS, AND THE AUTHORS AND DISTRIBUTORS HAVE
# NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS,
# OR MODIFICATIONS.
# 
# GOVERNMENT USE: If you are acquiring this software on behalf of the
# U.S. government, the Government shall have only "Restricted Rights"
# in the software and related documentation as defined in the Federal
# Acquisition Regulations (FARs) in Clause 52.227.19 (c) (2).  If you
# are acquiring the software on behalf of the Department of Defense,
# the software shall be classified as "Commercial Computer Software"
# and the Government shall have only "Restricted Rights" as defined in
# Clause 252.227-7013 (c) (1) of DFARs.  Notwithstanding the foregoing,
# the authors grant the U.S. Government and others acting in its behalf
# permission to use and distribute the software in accordance with the
# terms specified in this license.
# Relational expressions are frequently nested to achieve some desired
# result. This nesting in normal Tcl syntax quickly gets difficult to read.
# Often the expression is naturally a pipe of the output of one command
# to the input of another. This idea came from the "Commands pipe" page
# on the wiki: http://wiki.tcl.tk/17419. The code here is different,
# but the idea is the same.
#
proc pipe {fns {var {}} {sep |~}} {
    # Split out the separator characters
    lassign [split $sep {}] s p
    # Split up the commands based on the separator character, pulling off the
    # first command.
    set pipeline [lassign [split $fns $s] cmd]
    # Trim off whitespace so that the input can be more free form.
    set cmd [string trim $cmd]
    # Iterate over the remaining elements in the pipeline
    foreach elem $pipeline {
        set elem [string trim $elem]
        # If there is no placeholder character in the command, then the
        # pipeline result is just placed as the last argument. Otherwise, the
        # accumulated pipeline is substituted for the placeholder.  N.B. the
        # use of "string map" implies that _all_ the placeholders will be
        # replaced.
        set cmd [expr {[string first $p $elem] == -1 ?\
            "$elem \[$cmd\]" : [string map [list $p "\[$cmd\]"] $elem]}]
    }
    # perform the command or save it into a variable
    if {$var eq {}} {
        return [uplevel 1 $cmd]
    } else {
        upvar 1 $var v
        set v $cmd
    }
}
