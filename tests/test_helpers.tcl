namespace eval TestHelpers {}


proc TestHelpers::readFile {filename} {
  set fp [open $filename r]
  set data [split [read $fp] "\n"]
  close $fp
  return $data
}
