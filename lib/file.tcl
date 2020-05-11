# File routines
#
# Copyright (C) 2020 Lawrence Woodman <lwoodman@vlifesystems.com>
# Licensed under an MIT licence.  Please see LICENCE.md for details.


proc readFile {filename} {
  set fp [open $filename r]
  set data [split [read $fp] "\n"]
  close $fp
  return $data
}


proc outputListing {listing listingFilename srcFilename} {
  set fp [open $listingFilename w]
  puts $fp "Listing - File: $srcFilename"
  puts $fp "[string repeat "=" \
       [expr {[string length $srcFilename]+16}]]\n\n"
  foreach l $listing {
    puts $fp $l
  }
  close $fp
}
