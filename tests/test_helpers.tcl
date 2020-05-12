namespace eval TestHelpers {}


proc TestHelpers::readFile {filename} {
  set fp [open $filename r]
  set data [read $fp]
  close $fp
  return $data
}
