package require Tcl 8.6
package require xproc

set ThisScriptDir [file dirname [info script]]

set summary [
  xproc::runTestFiles -directory $ThisScriptDir {*}$argv
]

dict with summary {
  puts "\nall.tcl:  Total: $total,  Passed: $passed,  Skipped: $skipped,  Failed: $failed"
}
if {[dict get $summary failed] > 0} {
  exit 1
}
