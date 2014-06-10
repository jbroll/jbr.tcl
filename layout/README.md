
**Layout is a DSL for Tcl/Tk user interface specification.**

Tk is a very popular user interface toolkit.  When being used from Tcl its main
drawback is that every Tk widget needs a name.  Most of the names will only be
used to create and then place the widgets on the screen, they are often no
longer needed after initialization.  Layout allows an interface to be build
without explicite widget naming.

It also provides a text based 2d pictorial mini language for widget container
specification.

All the widget commands in the layout system follow the Tk widget command API
conventions:

  * All options are followed by a value
  * The command returns the widget name

Some commands act as container commands.  These container commands accept a
single final argument that defines the content of the container.  The command
"layout" is the primary container.  The content of the layout container
consists of a list of widget and container commands and grid syntax marks.
These are the standard grid pseudo options, plus "." and "&".

**Grid syntax:**

 * "-" - Streach the widget to the next cell
 * "x" - Empty cell
 * "." - No op.  can be used to introduce global options.
 * "&" - Move to next row or column.
 * "??" - debug output, print the next widget command encountered.

**Example:**

    proc hello {} { puts hello } 

    layout -in . {
	button -text Hello -command "hello"
    }

Abreviated names are provided for the most common widgets, but the any commands
that follow the Tk widget creation conventions will work with layout.

**Standard abrevioation:**

  * "@" - text
  * "!" - button
  * "=" - entry
  * "*" - radiobutton
  * "~" - checkbutton

**Abreviated Example:**

    proc hello {} { puts hello } 

    layout -in . {
	! Hello
    }

**Longer example:

    layout in . {
	# Global options
	# Every one is sticky, column 1 is strechy, labels are a little bigger than default
	#
	-sticky news
	-colweight 1
	-label.pady 6

	# A row of a label, "Start" button, "Stop" button and status label.  The
	# widget name of the status label of stored in ::status so that its text
	# can be updated by the script.
	#
	@ Guide ! "Start" -command guide-start ! "Stop"       -command guide-stop @ ::status Status
	&   @ View  ! "Boxes" -command view-boxes  ! "Full Image" -command view-full ! "All Images" -command view-all

	# These radiobuttons all set the fiber variable and call "set-fiber"
	#
	&   . -radiobutton.variable fiber
	. -radiobutton.command "set-fiber"

	@ Fiber  radiobutton -text Large  -value large
	radiobutton -text Medium -value medium
	radiobutton -text Small  -value small
	&   ! "Guide at Offset Position" -command guide-at-offset   x
	    row -background red -sticky news {
	    -label.pady 6
		-label.padx 4

		-sticky news
		@ "X Offset" = XOff -width 5
		@ "Y Offset" = YOff -width 5 } -
		&   ! ::transfer "Transfer Box"  -command guide-transfer x ! "Guide on target" ! "Guide on star"
		&   ! "Guide at Fiber Position"  -command guide-at-fiber
		&   ! "Combine Guide Images" -command guide-combine x = count -width 6 -justify r ! "Clear Images" -command clear-im
		&   x @ "Output Image" = imdir -width 10
		&   @ ""
		&   @ "Exposure Times" -anchor n
		row {
		    label -width 7

		    . -entry.width 5

		    @ "Target"     = box1exp1 ! Set -command "setexp box1 1" = box1exp2 ! Set -command "setexp box1 2"
		    & x @ "Guide Star" = box2exp1 ! Set -command "setexp box2 1" = box2exp2 ! Set -command "setexp box2 2"
		    & x @ "Full Image" = fullexp1 ! Set -command "setexp full 1" = fullexp2 ! Set -command "setexp full 2"
		} - -
    }

**Global Options:**

**Container Types:**

  * layout - Top level container
  * row - Alias for layout, used inside a layout to provide row oriented sub-frames
  * col - Alias for "layout -type col", provides column oriented suub-frames.
  * notebook - Container is a list of "page" containers.
    * page -  Row oriented container used inside a notebook.
  * paned - Container is a list of panes, vertically adjustable interface frames.
    * pane - Row oriented container used inside a paned widget.

**Layout API**

Any Tk widget command may be used in a layout container with out additional
specification.  When it is encountered in an expected widget command position
it will be called to create its interface element.  Additional widgets and
containers may be added to the layout system using the layout API.  When 
declaired commands will be able to have global and default options filled
in and passed correctly and be able to participate as containers.

**Declairation API**

  * layout.debug
  * layout.register
  * layout.macro
  * layout.option

**Options API**

  * layout.default.$option
  * layout.$command.$option

  * layout.options

**Layout Container API**

  * layout.$container.grid


