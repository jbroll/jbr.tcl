# FM & AMG : https://wiki.tcl-lang.org/page/Unique+Element+List
# 
#  ensemble --> ring

package require struct::set
namespace eval ring {
    namespace ensemble create -subcommands {
        empty size contains union intersect difference symdiff intersect3 equal include exclude add substract subsetof
    }
}
interp alias {} ring::empty      {} struct::set empty
interp alias {} ring::size       {} struct::set size
interp alias {} ring::contains   {} struct::set contains
interp alias {} ring::union      {} struct::set union
interp alias {} ring::intersect  {} struct::set intersect
interp alias {} ring::difference {} struct::set difference
interp alias {} ring::symdiff    {} struct::set symdiff
interp alias {} ring::intersect3 {} struct::set intersect3
interp alias {} ring::equal      {} struct::set equal
interp alias {} ring::include    {} struct::set include
interp alias {} ring::exclude    {} struct::set exclude
interp alias {} ring::add        {} struct::set add
interp alias {} ring::substract  {} struct::set substract
interp alias {} ring::subsetof   {} struct::set subsetof
