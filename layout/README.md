# Tcl/Tk UI Framework

A domain-specific language and object-oriented canvas system for building
Tcl/Tk user interfaces without explicit widget naming. Includes integrated
message passing for dynamic updates.

## Components

- **[Layout](Layout.md)** - DSL for creating widget layouts using grid-based syntax with automatic naming
- **[Canvas](Canvas.md)** - Object-oriented canvas with hierarchical coordinate systems and transformations

Both components support binding widget properties and shape attributes to
message servers or global variables for real-time updates.
