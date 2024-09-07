
# Testing
# New test suite
package require Tcl 8.5.7
source json.tcl
package require tcltest

foreach {name description input output} {
    json-1.1 "encode array document"
    {array {{number 0} {number 1} {number 2} {number 3}}} {[0,1,2,3]}

    json-1.2 "encode object document"
    {object {foo {number 0} bar {number 1} quux {number 2}}}
    {{"foo":0,"bar":1,"quux":2}}

    json-1.3.1 "encode string document"
    {string "hello world"} {"hello world"}

    json-1.3.2 "encode empty string document"
    {string ""} {""}

    json-1.3.3 "encode NUL string document"
    {string "\x00"} {"\u0000"}

    json-1.3.4 "encode quoted string document"
    {string "\x1f\\x\"y\"z"} {"\u001f\\x\"y\"z"}

    json-1.4.1 "encode integer number document"
    {number 42} 42

    json-1.4.2 "encode negative integer number document"
    {number -42} -42

    json-1.4.3 "encode positive integer number document"
    {number +42} 42

    json-1.4.4 "encode spaced integer number document"
    {number " +084 "} 84

    json-1.4.5 "encode real number document"
    {number 4.2} 4.2

    json-1.4.6 "encode negative real number document"
    {number -4.2} -4.2

    json-1.4.6 "encode positive real number document"
    {number +4.2} 4.2

    json-1.4.7 "encode spaced real number document"
    {number " +04.20 "} 4.2

    json-1.4.8 "encode real number document w/o leading zero"
    {number -.2} -0.2

    json-1.4.9 "encode real number document w/o trailing zero"
    {number +2.} 2.0

    json-1.4.10 "encode exponential number document"
    {number 2e5} 2.0e+5

    json-1.5.1 "encode literal true document"
    {literal true} true

    json-1.5.2 "encode literal false document"
    {literal false} false

    json-1.5.3 "encode literal null document"
    {literal null} null

    json-1.6 "encode pre-encoded document"
    {encoded {"hello world"}} {"hello world"}

    json-1.7 "encode decoded document"
    {decoded {string "hello world"}} {"hello world"}

    json-1.8.1 "encode array array document"
    {{array array} {{{number 1} {number 2}} {{string 3}}}} {[[1,2],["3"]]}

    json-1.8.2 "encode array array number document"
    {{array array number} {{1 2} {3 4}}} {[[1,2],[3,4]]}

    json-1.8.3 "encode array object document"
    {{array object} {{a {number 1} b {string 2}} {a {string 3} b {number 4}}}}
    {[{"a":1,"b":"2"},{"a":"3","b":4}]}

    json-1.8.4 "encode array object number document"
    {{array object number} {{a 1 b 2} {a 3 b 4}}}
    {[{"a":1,"b":2},{"a":3,"b":4}]}

    json-1.8.5 "encode array string document"
    {{array string} {1 2 3 4}} {["1","2","3","4"]}

    json-1.8.6 "encode array number document"
    {{array number} {1 2 3 4}} {[1,2,3,4]}

    json-1.8.7 "encode array literal document"
    {{array literal} {true false null}} {[true,false,null]}

    json-1.8.8 "encode array encoded document"
    {{array encoded} {{"x"} [0,0] null}} {["x",[0,0],null]}

    json-1.8.9 "encode array decoded document"
    {{array decoded} {{literal true} {literal false} {literal null}}}
    {[true,false,null]}

    json-1.9.1 "encode object array document"
    {{object array} {a {{number 1} {number 2}} b {{string 3}}}}
    {{"a":[1,2],"b":["3"]}}

    json-1.9.2 "encode object array number document"
    {{object array number} {a {1 2} b {3 4}}} {{"a":[1,2],"b":[3,4]}}

    json-1.9.3 "encode object object document"
    {{object object} {x {a {number 1} b {string 2}} y {a {string 3}}}}
    {{"x":{"a":1,"b":"2"},"y":{"a":"3"}}}

    json-1.9.4 "encode object object number document"
    {{object object number} {x {a 1 b 2} y {a 3 b 4}}}
    {{"x":{"a":1,"b":2},"y":{"a":3,"b":4}}}

    json-1.9.5 "encode object string document"
    {{object string} {1 2 3 4}} {{"1":"2","3":"4"}}

    json-1.9.6 "encode object number document"
    {{object number} {1 2 3 4}} {{"1":2,"3":4}}

    json-1.9.7 "encode object literal document"
    {{object literal} {true true false false null null}}
    {{"true":true,"false":false,"null":null}}

    json-1.9.8 "encode object encoded document"
    {{object encoded} {true {"x"} false [0,0] null null}}
    {{"true":"x","false":[0,0],"null":null}}

    json-1.9.9 "encode object decoded document"
    {{object decoded} {true {string x} false {number -1.20} null {literal null}}}
    {{"true":"x","false":-1.2,"null":null}}
} {
    tcltest::test $name $description -body [list json::encode $input]\
            -result $output
}

# TODO: more error cases?
tcltest::test json-1.5.4 "encode literal invalid document" -body {
    json::encode {literal invalid}
} -returnCodes error\
-result {invalid JSON literal "invalid": must be false, null, or true}

foreach {name description input output} {
    json-2.1 "decode array document"
    {[0,1,2,3]} {array {{number 0} {number 1} {number 2} {number 3}}}

    json-2.2 "decode object document"
    {{"foo":0,"bar":1,"quux":2}}
    {object {foo {number 0} bar {number 1} quux {number 2}}}

    json-2.3.1 "decode string document"
    {"hello world"} {string {hello world}}

    json-2.3.2 "decode empty string document"
    {""} {string {}}

    json-2.3.3 "decode NUL string document"
    {"\u0000"} "string \x00"

    json-2.3.4 "decode quoted string document"
    {"\u001f\\x\"y\"z"} "string {\x1f\\x\"y\"z}"

    json-2.4.1 "decode integer number document"
    42 {number 42}

    json-2.4.2 "decode negative integer number document"
    -42 {number -42}

    json-2.4.3 "decode positive integer number document"
    +42 {number 42}

    json-2.4.5 "decode real number document"
    4.2 {number 4.2}

    json-2.4.6 "decode negative real number document"
    -4.2 {number -4.2}

    json-2.4.6 "decode positive real number document"
    +4.2 {number 4.2}

    json-2.5.1 "decode literal true document"
    true {literal true}

    json-2.5.2 "decode literal false document"
    false {literal false}

    json-2.5.3 "decode literal null document"
    null {literal null}

    json-2.6.1 "decode array array document"
    {[[1],["3"]]} {array {{array {{number 1}}} {array {{string 3}}}}}

    json-2.6.2 "decode array array number document"
    {[[1,2],[3,4]]}
    {array {{array {{number 1} {number 2}}} {array {{number 3} {number 4}}}}}

    json-2.6.3 "decode array object document"
    {[{"a":1,"b":"2"},{"a":"3"}]}
    {array {{object {a {number 1} b {string 2}}} {object {a {string 3}}}}}

    json-2.6.4 "encode array string document"
    {["1","2","3","4"]} {array {{string 1} {string 2} {string 3} {string 4}}}

    json-2.6.5 "decode array number document"
    {[1,2,3,4]} {array {{number 1} {number 2} {number 3} {number 4}}}

    json-2.6.6 "decode array literal document"
    {[true,false,null]} {array {{literal true} {literal false} {literal null}}}

    json-2.7.1 "decode object array document"
    {{"a":[1,2],"b":["3"]}}
    {object {a {array {{number 1} {number 2}}} b {array {{string 3}}}}}

    json-2.7.2 "decode object object document"
    {{"x":{"a":1,"b":"2"},"y":{"a":"3"}}}
    {object {x {object {a {number 1} b {string 2}}} y {object {a {string 3}}}}}

    json-2.7.3 "decode object string document"
    {{"1":"2","3":"4"}} {object {1 {string 2} 3 {string 4}}}

    json-2.7.4 "encode object number document"
    {{"1":2,"3":4}} {object {1 {number 2} 3 {number 4}}}

    json-2.7.5 "decode object literal document"
    {{"true":true,"false":false,"null":null}}
    {object {true {literal true} false {literal false} null {literal null}}}
} {
    tcltest::test $name $description -body [list json::decode $input]\
            -result $output
}

foreach {name description input output} {
    json-3.1 "array schema"
    {array {{number 0} {number 1} {number 2} {number 3}}}
    {array {number number number number}}

    json-3.2 "object schema"
    {object {foo {number 0} bar {number 1} quux {number 2}}}
    {object {foo number bar number quux number}}

    json-3.3 "string schema"
    {string {hello world}} string

    json-3.4 "number schema"
    {number 42} number

    json-3.5 "literal schema"
    {literal true} literal

    json-3.6.1 "array array schema"
    {array {{array {{number 1}}} {array {{string 3} {literal false}}}}}
    {array {{array number} {array {string literal}}}}

    json-3.6.2 "array array number schema"
    {array {{array {{number 1} {number 2}}} {array {{number 3} {number 4}}}}}
    {array {{array {number number}} {array {number number}}}}

    json-3.6.3 "array object schema"
    {array {{object {a {number 1} b {string 2}}} {object {a {string 3}}}}}
    {array {{object {a number b string}} {object {a string}}}}

    json-3.6.4 "array string schema"
    {array {{string 1} {string 2} {string 3} {string 4}}}
    {array {string string string string}}

    json-3.6.5 "array number schema"
    {array {{number 1} {number 2} {number 3} {number 4}}}
    {array {number number number number}}

    json-3.6.6 "array literal schema"
    {array {{literal true} {literal false} {literal null}}}
    {array {literal literal literal}}

    json-3.7.1 "object array schema"
    {object {a {array {{number 1} {number 2}}} b {array {{string 3}}}}}
    {object {a {array {number number}} b {array string}}}

    json-3.7.2 "object object schema"
    {object {x {object {a {number 1} b {string 2}}} y {object {a {string 3}}}}}
    {object {x {object {a number b string}} y {object {a string}}}}

    json-3.7.3 "object string schema"
    {object {1 {string 2} 3 {string 4}}}
    {object {1 string 3 string}}

    json-3.7.4 "object number schema"
    {object {1 {number 2} 3 {number 4}}}
    {object {1 number 3 number}}

    json-3.7.5 "object literal schema"
    {object {true {literal true} false {literal false} null {literal null}}}
    {object {true literal false literal null literal}}
} {
    tcltest::test $name $description -body [list json::schema $input]\
            -result $output
}

foreach {name description input output} {
    json-4.1 "array values"
    {array {{number 0} {number 1} {number 2} {number 3}}} {0 1 2 3}

    json-4.2 "object values"
    {object {foo {number 0} bar {number 1} quux {number 2}}}
    {foo 0 bar 1 quux 2}

    json-4.3 "string values"
    {string {hello world}} {hello world}

    json-4.4 "number values"
    {number 42} 42

    json-4.5 "literal values"
    {literal true} true

    json-4.6.1 "array array values"
    {array {{array {{number 1}}} {array {{string 3} {literal false}}}}}
    {1 {3 false}}

    json-4.6.2 "array array number values"
    {array {{array {{number 1} {number 2}}} {array {{number 3} {number 4}}}}}
    {{1 2} {3 4}}

    json-4.6.3 "array object values"
    {array {{object {a {number 1} b {string 2}}} {object {a {string 3}}}}}
    {{a 1 b 2} {a 3}}

    json-4.6.4 "array string values"
    {array {{string 1} {string 2} {string 3} {string 4}}} {1 2 3 4}

    json-4.6.5 "array number values"
    {array {{number 1} {number 2} {number 3} {number 4}}} {1 2 3 4}

    json-4.6.6 "array literal values"
    {array {{literal true} {literal false} {literal null}}} {true false null}

    json-4.7.1 "object array values"
    {object {a {array {{number 1} {number 2}}} b {array {{string 3}}}}}
    {a {1 2} b 3}

    json-4.7.2 "object object values"
    {object {x {object {a {number 1} b {string 2}}} y {object {a {string 3}}}}}
    {x {a 1 b 2} y {a 3}}

    json-4.7.3 "object string values"
    {object {1 {string 2} 3 {string 4}}} {1 2 3 4}

    json-4.7.4 "object number values"
    {object {1 {number 2} 3 {number 4}}} {1 2 3 4}

    json-4.7.5 "object literal values"
    {object {true {literal true} false {literal false} null {literal null}}}
    {true true false false null null}
} {
    tcltest::test $name $description -body [list json::values $input]\
            -result $output
}

foreach {name description schema values output} {
    json-5.1 "unite array"
    {array {number number number number}} {0 1 2 3}
    {array {{number 0} {number 1} {number 2} {number 3}}}

    json-5.2 "unite object"
    {object {foo number bar number quux number}} {foo 0 bar 1 quux 2}
    {object {foo {number 0} bar {number 1} quux {number 2}}}

    json-5.3 "unite string"
    string {hello world} {string {hello world}}

    json-5.4 "unite number"
    number 42 {number 42}

    json-5.5 "unite literal"
    literal true {literal true}

    json-5.6.1 "unite array array"
    {array {{array number} {array {string literal}}}} {1 {3 false}}
    {array {{array {{number 1}}} {array {{string 3} {literal false}}}}}

    json-5.6.2 "unite array array number"
    {array {{array {number number}} {array {number number}}}} {{1 2} {3 4}}
    {array {{array {{number 1} {number 2}}} {array {{number 3} {number 4}}}}}

    json-5.6.3 "unite array object"
    {array {{object {a number b string}} {object {a string}}}} {{a 1 b 2} {a 3}}
    {array {{object {a {number 1} b {string 2}}} {object {a {string 3}}}}}

    json-5.6.4 "unite array string"
    {array {string string string string}} {1 2 3 4}
    {array {{string 1} {string 2} {string 3} {string 4}}}

    json-5.6.5 "unite array number"
    {array {number number number number}} {1 2 3 4}
    {array {{number 1} {number 2} {number 3} {number 4}}}

    json-5.6.6 "unite array literal"
    {array {literal literal literal}} {true false null}
    {array {{literal true} {literal false} {literal null}}}

    json-5.7.1 "unite object array"
    {object {a {array {number number}} b {array string}}} {a {1 2} b 3}
    {object {a {array {{number 1} {number 2}}} b {array {{string 3}}}}}

    json-5.7.2 "unite object object"
    {object {x {object {a number b string}} y {object {a string}}}}
    {x {a 1 b 2} y {a 3}}
    {object {x {object {a {number 1} b {string 2}}} y {object {a {string 3}}}}}

    json-5.7.3 "unite object string"
    {object {1 string 3 string}} {1 2 3 4} {object {1 {string 2} 3 {string 4}}}

    json-5.7.4 "unite object number"
    {object {1 number 3 number}} {1 2 3 4} {object {1 {number 2} 3 {number 4}}}

    json-5.7.5 "unite object literal"
    {object {true literal false literal null literal}}
    {true true false false null null}
    {object {true {literal true} false {literal false} null {literal null}}}
} {
    tcltest::test $name $description -body [list json::unite $schema $values]\
            -result $output
}

tcltest::cleanupTests
# Old test suite
package require tcltest
foreach {name json::encode json::decode description tcl json} {
    1.1 1 1 "empty string"
        {string {}}
        {""}
    1.2 1 1 "nonempty string"
        {string hello}
        {"hello"}
    1.3 1 0 "string with quoted characters"
        {string \"a\nb\\c\"}
        {"\"a\u000ab\\c\""}
    1.4 1 1 "string with canonical quoted characters"
        "string \{\"a\nb\\c\"\}"
        {"\"a\u000ab\\c\""}
    2.1 1 1 integer
        {number 42}
        42
    2.2 1 1 "negative integer"
        {number -42}
        -42
    2.3 1 0 "positive integer"
        {number +42}
        42
    2.4 1 0 "leading zeroes"
        {number 000}
        0
    2.5 1 1 zero
        {number 0}
        0
    2.6 1 1 "negative zero"
        {number -0}
        -0
    2.7 1 0 "negative zero with leading zeroes"
        {number -000}
        -0
    2.8 1 1 "real number"
        {number 1.23}
        1.23
    2.9 1 1 "negative real number"
        {number -1.23}
        -1.23
    2.10 1 1 "negative real number with exponent"
        {number -1.0e+5}
        -1.0e+5
    2.11 1 1 "real number with capital exponent"
        {number 1.0e+5}
        1.0e+5
    2.12 1 1 "real number with fraction and exponent"
        {number 1.23e+4}
        1.23e+4
    2.13 1 0 "positive real number with fraction and positive exponent"
        {number +1.23e+4}
        1.23e+4
    2.14 1 1 "real number with fraction and negative exponent"
        {number 1.23e-4}
        1.23e-4
    2.15 1 0 "real number with dot and no fraction"
        {number 1.}
        1.0
    2.16 1 0 "real number with dot and no integer"
        {number .1}
        0.1
    2.17 1 0 "real number with dot, no fraction, and exponent"
        {number 1.E5}
        1.0e+5
    2.18 1 0 "real number with dot, no integer, and exponent"
        {number .1E-5}
        0.1e-5
    2.19 1 0 "real number with leading zeroes"
        {number 00123.45}
        123.45
    2.20 1 0 "small real number with leading zeroes"
        {number 00000.45}
        0.45
    2.21 1 0 "zero real number with leading zeroes and exponent"
        {number 00000e9}
        0.0e+9
    3.1 1 1 "literal false"
        {literal false}
        false
    3.2 1 1 "literal null"
        {literal null}
        null
    3.3 1 1 "literal true"
        {literal true}
        true
    4.1 1 1 "array with variable type"
        {array {{string hello} {number 42} {literal null}}}
        {["hello",42,null]}
    4.2 1 1 "array with constant but unshared type"
        {array {{array {{number 1} {number 2}}} {array {{number 3} {number 4}}}}}
        {[[1,2],[3,4]]}
    4.3 1 0 "array with shared type, nested syntax"
        {{array {array number}} {{1 2} {3 4}}}
        {[[1,2],[3,4]]}
    4.4 1 0 "array with shared type, flattened syntax"
        {{array array number} {{1 2} {3 4}}}
        {[[1,2],[3,4]]}
    4.5 1 0 "array of strings"
        {{array array string} {{1 2} {3 4}}}
        {[["1","2"],["3","4"]]}
    4.6 1 1 "empty array"
        {array {}}
        {[]}
    4.7 1 0 "empty array with unnecessary shared type"
        {{array string} {}}
        {[]}
    5.1 1 1 "object with variable type"
        {object {foo {string hello} bar {number 42} quux {literal null}}}
        {{"foo":"hello","bar":42,"quux":null}}
    5.2 1 1 "object with constant but unshared type"
        {object {name {object {first {string Andy} last {string Goth}}} address {object {web {string https://www.tcl-lang.org/}}}}}
        {{"name":{"first":"Andy","last":"Goth"},"address":{"web":"https://www.tcl-lang.org/"}}}
    5.3 1 0 "object with shared type, flattened syntax"
        {{object object string} {name {first Andy last Goth} address {web https://www.tcl-lang.org/}}}
        {{"name":{"first":"Andy","last":"Goth"},"address":{"web":"https://www.tcl-lang.org/"}}}
    5.4 1 1 "empty object"
        {object {}}
        {{}}
    5.5 1 0 "empty object with unnecessary shared type"
        {{object string} {}}
        {{}}
    6.1 1 0 "empty raw"
        {encoded {}}
        {}
    6.2 1 0 "nonempty raw"
        {encoded {"foobar"}}
        {"foobar"}
} {
    if {$json::encode} {
        tcltest::test json::encode-$name $description\
                -body [list json::encode $tcl] -result $json
    }
    if {$json::decode} {
        tcltest::test json::decode-$name $description\
                -body [list json::decode $json] -result $tcl
    }
}
tcltest::cleanupTests
