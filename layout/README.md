
Layout is a DSL for Tcl/Tk user interface specification.

Tk is a very popular user interface toolkit.  When being used from Tcl its main drawback 
is that every Tk widget needs a name.  Most of the names will only be used to create
and then place the widgets on the screen, they are often no longer needed after initialization.
Layout allows an interface to be build without explicite widget naming.

It also provides a text base 2d pictorial mini language for widget container specification.

All the widget commands in the layout system have options that follow the Tk widget command
conventions:

  * All options are followed by a value
  * The command returns the widget name

Some commands act as container commands.  These commands accept a single final argument that 
defines the content of the container.  The command "layout" is the primary container.
The content of the layout container consists of a list of widget and container commands and 
grid syntax marks.  These are the standard grid pseudo options, plus "." and "&".

Grid syntax:

 * "-" - Streach the widget to the next cell
 * "x" - Empty cell
 * "." - No op.  can be used to introduce global options.
 * "&" - Move to next row or column.

Example:

    proc hello {} { puts hello } 

    layout -in . {
	button -text Hello -command "hello"
    }

Abreviated names are provided for the most common widgets, but the any commands that follow the Tk 
widget creation conventions will work with layout.

Standard abrevioation:

  * @ text
  * ! button
  * = entry
  * * radiobutton
  * ~ checkbutton

Abreviated Example:

    proc hello {} { puts hello } 

    layout -in . {
	! Hello
    }





