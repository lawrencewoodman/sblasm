# File routines
#
# Copyright (C) 2020 Lawrence Woodman <lwoodman@vlifesystems.com>
# Licensed under an MIT licence.  Please see LICENCE.md for details.


proc readFile {filename} {
  set fp [open $filename r]
  set data [read $fp]
  close $fp
  return $data
}


proc outputListing {listing listingFilename} {
  set fp [open $listingFilename w]
  puts $fp "Listing\n=======\n\n"
  puts $fp $listing
  close $fp
}
