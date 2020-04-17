namespace eval TestHelpers {}


proc TestHelpers::readFile {filename} {
 # TODO: Add Error handling
  set fp [open $filename r]
  set data [split [read $fp] "\n"]
  close $fp
  return $data
}
