# layout-treeview.tcl -- ttk::treeview widget support for layout DSL
#
# This module adds ttk::treeview widget support to the jbr.tcl layout system.
# Treeview widgets provide hierarchical tree/list displays with columns.
#
# Usage in layout DSL:
#   tree varname -columns {col1 col2} -show {tree headings} -height 20
#
# The widget is registered with common treeview options and can be used
# with the 'tree' macro shorthand.

# Register the ttk::treeview widget with its standard options
layout.register ttk::treeview {
    -columns
    -displaycolumns
    -show
    -height
    -selectmode
    -yscrollcommand
    -xscrollcommand
    -padding
    -style
    -takefocus
}

# Define the 'tree' macro as shorthand for ttk::treeview
# This allows using 'tree' instead of the full widget name in layouts
layout.macro tree { layout.replace ttk::treeview }

# Helper proc to configure treeview columns with headings
# Usage: layout.treeview.columns .tree {id "ID" name "Name" size "Size"}
proc layout.treeview.columns {w colspec} {
    foreach {col heading} $colspec {
        $w heading $col -text $heading
    }
}

# Helper proc to configure column widths
# Usage: layout.treeview.widths .tree {id 50 name 200 size 100}
proc layout.treeview.widths {w widthspec} {
    foreach {col width} $widthspec {
        $w column $col -width $width
    }
}

# Helper to add scrollbars to a treeview
# Usage: layout.treeview.scrolled .parent varname {tree options...}
# Returns the treeview widget path
proc layout.treeview.scrolled {parent name args} {
    set tree ${parent}.${name}
    set vsb ${parent}.${name}_vsb
    set hsb ${parent}.${name}_hsb

    ttk::treeview $tree -yscrollcommand [list $vsb set] \
                        -xscrollcommand [list $hsb set] {*}$args
    ttk::scrollbar $vsb -orient vertical -command [list $tree yview]
    ttk::scrollbar $hsb -orient horizontal -command [list $tree xview]

    grid $tree -row 0 -column 0 -sticky news
    grid $vsb -row 0 -column 1 -sticky ns
    grid $hsb -row 1 -column 0 -sticky ew

    grid columnconfigure $parent 0 -weight 1
    grid rowconfigure $parent 0 -weight 1

    return $tree
}

# Package provide
package provide jbr::layout::treeview 1.0
