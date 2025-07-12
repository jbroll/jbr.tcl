# Layout - A DSL for Tcl/Tk User Interface Specification

Layout is a domain-specific language for creating Tcl/Tk user interfaces without explicit widget naming. It provides a text-based 2D pictorial syntax for organizing widgets in grid layouts.

## Overview

Traditional Tk programming requires naming every widget, even when those names are only used for creation and placement. Layout eliminates this requirement by automatically generating widget names and providing intuitive syntax for common UI patterns.

## Basic Usage

```tcl
layout -in . {
    button -text Hello -command hello
}
```

All widget commands follow standard Tk conventions:
- Options are followed by values
- Commands return the widget name
- Container commands accept a final argument defining their content

## Grid Syntax

Layout uses special characters to control widget placement:

- `-` - Stretch widget to next cell (columnspan)
- `x` - Empty cell
- `.` - No operation (useful for global options)
- `&` - Move to next row
- `??` - Debug output for next widget

## Widget Abbreviations

Common widgets have single-character shortcuts:

- `@` - label
- `!` - button  
- `=` - entry
- `*` - radiobutton
- `~` - checkbutton
- `_` - horizontal separator
- `|` - vertical separator
- `?` - optmenu
- `?+` - combobox

## Example

```tcl
layout -in . {
    # Global options
    -sticky news
    -colweight 1
    -label.pady 6
    
    # Interface layout
    @ "Start:" ! "Start" -command start-process ! "Stop" -command stop-process
    & @ "Status:" @ ::status "Ready"
    & = filename -width 20 ! "Browse" -command select-file
}
```

## Global Options

Global options affect all subsequent widgets until overridden:

- `-sticky` - Widget stickiness (n,s,e,w combinations)
- `-colweight <col> <weight>` - Column stretch weight
- `-rowweight <row> <weight>` - Row stretch weight  
- `-<widget>.<option>` - Default option for widget type

## Container Types

### layout
The primary container type. Creates a frame and arranges children in a grid.

### row
Alias for `layout`, emphasizes horizontal arrangement.

### col  
Column-oriented layout (`layout -type col`).

### notebook
Creates a ttk::notebook with page containers:
```tcl
notebook {
    page "Tab 1" { 
        @ "Content 1" 
    }
    page "Tab 2" { 
        @ "Content 2" 
    }
}
```

### paned
Creates a panedwindow with adjustable panes:
```tcl
paned {
    pane { @ "Left panel" }
    pane { @ "Right panel" }
}
```

## Message Binding System

Layout integrates with a message passing system for dynamic widget updates. Widget options can be bound to server variables or global Tcl variables.

### Syntax

Bind widget options using the format: `server:variable,default`

```tcl
layout -in . {
    @ -text "PMACMMIRS:temperature,0.0"
    = -textvariable "PMACMMIRS:setpoint,25.0"
}
```

### Binding Types

- `server:variable,default` - Subscribe to server variable with fallback value
- `:variable` - Bind to global Tcl variable (server omitted)
- `variable@lookup` - Index into lookup list using variable value
- `variable%hash` - Look up value in hash array
- `variable!proc` - Transform value using procedure

### Examples

```tcl
layout -in . {
    # Direct server binding
    @ -text "MOTOR:position,0"
    
    # Global variable binding  
    @ -text ":status"
    
    # Lookup table
    @ -text "MOTOR:state@state_names,Unknown"
    
    # Hash lookup
    @ -text "MOTOR:error%error_messages,OK"
    
    # Procedure transformation
    @ -text "MOTOR:temp!format_temperature,--"
}
```

When bound, widgets automatically update when the associated variable changes. The system handles subscription setup and cleanup automatically.

## Advanced Features

### Macros
Define custom widget shortcuts:
```tcl
layout.macro mylabel { layout.replace label -background yellow }
```

### Default Value Handlers
Customize how default values are generated:
```tcl
proc layout.button.command { item option w defs Defs } {
    # Custom logic for button command defaults
}
```

### Widget Registration
Register new widget types:
```tcl
layout.register mywidget { -text -command } -proc { { w args } { 
    # Custom widget creation logic
}}
```

## Implementation Notes

- Widget names are automatically generated as `parent.w1`, `parent.w2`, etc.
- The system uses Tk's grid geometry manager
- Global options are stored and applied to matching widgets
- Container commands can be nested arbitrarily deep
- Debug output can be enabled with `set layout.debug 1`