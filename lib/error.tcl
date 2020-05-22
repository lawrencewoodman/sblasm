# Error routines
#
# Copyright (C) 2020 Lawrence Woodman <lwoodman@vlifesystems.com>
# Licensed under an MIT licence.  Please see LICENCE.md for details.


proc errorCompare {a b} {
  if {[dict exists $a filename] && [dict exists $b filename]} {
    set aFilename [dict get $a filename]
    set bFilename [dict get $b filename]
    set abFilenameCmp [string compare $aFilename $bFilename]
    if {$abFilenameCmp != 0} {return $abFilenameCmp}
    return [expr {[dict get $a lineNum] - [dict get $b lineNum]}]
  }
  return 0
}
