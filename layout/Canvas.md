# Canvas - Object-Oriented Canvas with Coordinate Systems

Canvas provides an object-oriented interface for creating and managing shapes on Tk canvases. It features hierarchical coordinate systems, linear transformations, and integration with message passing for dynamic updates.

## Overview

The canvas system consists of two main classes:
- `canvas-oo` - Core canvas with coordinate systems and transformations
- `canvas-msg` - Extends canvas-oo with message binding capabilities

Each shape exists within a coordinate system that can be translated, rotated, and scaled. Coordinate systems can contain other coordinate systems, creating transformation hierarchies.

## Basic Usage

```tcl
set canvas [canvas .c]
canvas-oo create drawer $canvas

# Create shapes
drawer rect 10 20 100 50 -fill red
drawer text 0 0 "Hello" -anchor center
drawer line 0 0 100 100 -width 2
```

## Coordinate Systems

Every shape belongs to a coordinate system. Create nested coordinate systems for complex transformations:

```tcl
# Create a coordinate system at (100,100) rotated 45 degrees
set cs1 [drawer csys 100 100 arm1 -rot 45]

# Draw in the rotated coordinate system  
drawer rect 0 0 50 20 -in $cs1 -fill blue

# Create another coordinate system within the first
set cs2 [drawer csys 60 0 arm2 -rot 30 -in $cs1]
drawer oval 0 0 20 20 -in $cs2 -fill green
```

## Shape Methods

### Basic Shapes
- `rect x y width height` - Rectangle
- `oval x y width height` - Ellipse  
- `line x y coords` - Line with coordinate list
- `poly x y coords` - Polygon with coordinate list
- `arc x y width height` - Arc
- `text x y text` - Text

### Advanced Shapes  
- `ngon x y width height -sides n` - Regular n-sided polygon
- `csys x y id` - Coordinate system

### Shape Options
- `-rot angle` - Rotation in degrees
- `-scale factor` or `-scale {sx sy}` - Scaling
- `-in csys_id` - Parent coordinate system
- Standard Tk canvas options (`-fill`, `-outline`, `-width`, etc.)

## Transformation Operations

### Movement
```tcl
# Absolute positioning
drawer amov shape_id 50 75 30  ;# x, y, rotation

# Relative movement  
drawer rmov shape_id 10 5 15   ;# dx, dy, drotation
```

### Coordinate System Management
```tcl
# Move shape to different coordinate system
drawer amov shape_id 0 0 0 $new_csys

# Get/set shape size
drawer size shape_id 80 60
set current_size [drawer size shape_id]

# Get/set coordinates
drawer coords shape_id {0 0 100 100}
set coords [drawer coords shape_id]
```

### Cleanup
```tcl
# Remove shape and all children
drawer erase shape_id
```

## Message Binding System

The `canvas-msg` class extends `canvas-oo` with dynamic binding to message servers and global variables.

### Basic Syntax

Bind shape properties using: `server:variable,default`

```tcl
canvas-msg create drawer $canvas

# Bind position to server variables
drawer rect "MOTOR:x,0" "MOTOR:y,0" 50 25 -fill red

# Bind text content
drawer text 100 100 "STATUS:message,OK" -anchor center

# Bind rotation
drawer rect 0 0 30 30 -rot "GYRO:heading,0"
```

### Binding Types

Shape coordinates, transformations, and display options can all be bound:

#### Position Binding
```tcl
# X and Y coordinates
drawer rect "MOTOR:x,0" "MOTOR:y,0" 50 25

# Rotation  
drawer text 0 0 "Hello" -rot "COMPASS:bearing,0"
```

#### Size Binding
```tcl
# Width and height
drawer oval 0 0 "TANK:level,50" "TANK:level,50" -fill blue
```

#### Option Binding
```tcl
# Color based on status
drawer rect 0 0 50 25 -fill "STATUS:color,gray"

# Text content
drawer text 0 0 -text "SENSOR:reading,0.0"
```

#### Coordinate Lists
```tcl
# Entire coordinate list for complex shapes
drawer line 0 0 -coords "PATH:waypoints,{0 0 100 100}"
```

### Value Transformation

Transform bound values before applying them:

#### Lookup Tables
Use `@` to index into a list:
```tcl
# Map numeric status to text
drawer text 0 0 -text "STATUS:code@status_messages,Unknown"

# Define the lookup table
set status_messages {"OK" "Warning" "Error" "Critical"}
```

#### Hash Tables  
Use `%` to look up in an array:
```tcl
# Map error codes to colors
drawer rect 0 0 50 25 -fill "STATUS:error%error_colors,gray"

# Define the hash table
array set error_colors {
    0 green
    1 yellow  
    2 red
    default gray
}
```

#### Procedure Calls
Use `!` to transform values with a procedure:
```tcl
# Format temperature reading
drawer text 0 0 -text "SENSOR:temp!format_temp,--°C"

# Define the transformation
proc format_temp {value} {
    return [format "%.1f°C" $value]
}
```

### Global Variable Binding

Bind to global Tcl variables by omitting the server:
```tcl
# Bind to global variable
drawer text 0 0 -text ":current_status"

# Variable updates automatically reflected
set current_status "System Ready"
```

## Complete Example

```tcl
# Create canvas and drawer
canvas .c -width 400 -height 300
pack .c
canvas-msg create robot .c

# Robot base
set base [robot csys "ROBOT:x,200" "ROBOT:y,150" base]
robot rect 0 0 60 40 -in $base -fill gray50

# Robot arm (rotates with servo)
set arm1 [robot csys 25 0 arm1 -rot "SERVO1:angle,0" -in $base]
robot rect 0 0 80 15 -in $arm1 -fill blue

# End effector
set arm2 [robot csys 80 0 arm2 -rot "SERVO2:angle,0" -in $arm1]  
robot rect 0 0 30 10 -in $arm2 -fill red

# Status display
robot text 20 20 -text "STATUS:message,Ready" -anchor nw

# Temperature indicator with color coding
robot oval 350 50 30 30 -fill "TEMP:status%temp_colors,green"
robot text 350 80 -text "TEMP:value!format_temp,--°C" -anchor center

# Define color mapping and formatter
array set temp_colors {normal green warning yellow critical red}
proc format_temp {temp} { return [format "%.1f°C" $temp] }
```

## Implementation Details

- Transformations use 2D matrix operations for translation, rotation, and scaling
- Each coordinate system maintains its own transformation matrix
- Shapes automatically redraw when bound variables change
- Message subscriptions are managed automatically
- The system supports arbitrary nesting of coordinate systems
- Canvas coordinates use a Y-down coordinate system with origin at canvas center