# An extended proc implementation
#
# Copyright (C) 2019 Lawrence Woodman <lwoodman@vlifesystems.com>
# Licensed under an MIT licence.  Please see LICENCE.md for details.

package require Tcl 8.6
package require fileutil::traverse

namespace eval xproc {
  namespace export {[a-z]*}
  variable tests [dict create]
  variable descriptions [dict create]
}


###################################################################
# Descriptions for exported procedures are at the end
# of this file because certain functions need to be defined before
# xproc can be used to add the descriptions.
###################################################################


proc xproc::proc {procName procArgs procBody args} {
  array set options {interp {}}
  while {[llength $args]} {
    switch -glob -- [lindex $args 0] {
      -interp {set args [lassign $args - options(interp)]}
      -desc* {set args [lassign $args - options(description)]}
      -test {set args [lassign $args - options(test)]}
      -*      {return -code error "unknown option: [lindex $args 0]"}
      default break
    }
  }
  if {[llength $args] > 0} {
    return -code error "invalid number of arguments"
  }

  if {$options(interp) eq {}} {
    uplevel 1 [list proc $procName $procArgs $procBody]
  } else {
    $options(interp) eval [list proc $procName $procArgs $procBody]
  }

  if {[info exists options(description)]} {
    uplevel 1 [
      list xproc::describe -interp $options(interp) \
                           $procName $options(description)
    ]
  }

  if {[info exists options(test)]} {
    uplevel 1 [
      list xproc::test -interp $options(interp) $procName $options(test)
    ]
  }
}


proc xproc::remove {type args} {
  variable tests
  variable descriptions
  array set options {match {"*"} interp {}}
  while {[llength $args]} {
    switch -glob -- [lindex $args 0] {
      -interp {set args [lassign $args - options(interp)]}
      -match {set args [lassign $args - options(match)]}
      -*      {return -code error "unknown option: [lindex $args 0]"}
      default break
    }
  }
  if {[llength $args] > 0} {
    return -code error "invalid number of arguments"
  }

  set lambdaVars [dict create match $options(match) interp $options(interp)]
  switch $type {
    tests {
      set tests [
        LFilter $lambdaVars $tests {{vars test} {
          dict with test {
            if {[dict get $vars interp] ne $interp} {return true}
            expr {![MatchProcName [dict get $vars match] $name]}
          }
        } xproc}
      ]
    }
    descriptions {
      set descriptions [
        LFilter $lambdaVars $descriptions {{vars description} {
          set interp [dict get $description interp]
          set name [dict get $description name]
          if {[dict get $vars interp] ne $interp} {return true}
          expr {![MatchProcName [dict get $vars match] $name]}
        } xproc}
      ]
    }
    all {
      remove tests -match $options(match) -interp $options(interp)
      remove descriptions -match $options(match) -interp $options(interp)
    }
    default {return -code error "unknown type: $type"}
  }
}


proc xproc::test {args} {
  variable tests
  array set options {id 1 interp {}}
  while {[llength $args]} {
    switch -glob -- [lindex $args 0] {
      -id     {set args [lassign $args - options(id)]}
      -interp {set args [lassign $args - options(interp)]}
      --      {set args [lrange $args 1 end] ; break}
      -*      {return -code error "unknown option: [lindex $args 0]"}
      default break
    }
  }
  if {[llength $args] != 2} {
    return -code error "invalid number of arguments"
  }
  if {![string is integer $options(id)] || $options(id) < 1} {
    return -code error "invalid id: $options(id)"
  }
  if {![interp exists $options(interp)]} {
    return -code error "interpreter doesn't exist: $options(interp)"
  }

  lassign $args procName lambda

  if {$options(interp) eq {}} {
    set fullProcName [uplevel 1 [list namespace which -command $procName]]
  } else {
    set fullProcName [
      $options(interp) eval [list namespace which -command $procName]
    ]
  }

  if {$fullProcName eq ""} {
    return -code error "procedureName doesn't exist: $procName"
  }

  if {[TestExists $tests $options(interp) $fullProcName $options(id)]} {
    if {$options(interp) eq {}} {
      return -code error "test already exists for procedure: $fullProcName, id: $options(id)"
    } else {
      return -code error "test already exists for interp: $options(interp), procedure: $fullProcName, id: $options(id)"
    }
  }

  lappend tests [
    dict create interp $options(interp) \
                name $fullProcName id $options(id) lambda $lambda
  ]
}


proc xproc::describe {args} {
  variable descriptions
  array set options {interp {}}
  while {[llength $args]} {
    switch -glob -- [lindex $args 0] {
      -interp {set args [lassign $args - options(interp)]}
      --      {set args [lrange $args 1 end] ; break}
      -*      {return -code error "unknown option: [lindex $args 0]"}
      default break
    }
  }
  if {[llength $args] != 2} {
    return -code error "invalid number of arguments"
  }
  if {![interp exists $options(interp)]} {
    return -code error "interpreter doesn't exist: $options(interp)"
  }
  lassign $args procName description

  if {$options(interp) eq {}} {
    set fullProcName [uplevel 1 [list namespace which -command $procName]]
  } else {
    set fullProcName [
      $options(interp) eval [list namespace which -command $procName]
    ]
  }
  if {$fullProcName eq ""} {
    return -code error "procedureName doesn't exist: $procName"
  }

  if {[DescriptionExists $descriptions $options(interp) $fullProcName]} {
    if {$options(interp) eq {}} {
      return -code error "description already exists for procedure: $fullProcName"
    } else {
      return -code error "description already exists for interp: $options(interp), procedure: $fullProcName"
    }
  }

  lappend descriptions [
    dict create interp $options(interp) \
                name $fullProcName \
                description [TidyDescription $description]
  ]
}


proc xproc::runTests {args} {
  variable tests

  array set options {channel stdout match {"*"} verbose 1 interp {}}
  while {[llength $args]} {
    switch -glob -- [lindex $args 0] {
      -channel {set args [lassign $args - options(channel)]}
      -interp {set args [lassign $args - options(interp)]}
      -match {set args [lassign $args - options(match)]}
      -verbose {set args [lassign $args - options(verbose)]}
      -*      {return -code error "unknown option: [lindex $args 0]"}
      default break
    }
  }
  if {[llength $args] > 0} {
    return -code error "invalid number of arguments"
  }
  if {![interp exists $options(interp)]} {
    return -code error "interpreter doesn't exist: $options(interp)"
  }

  set tests [
    lmap test $tests {
      RunTest $options(interp) $test $options(verbose) \
              $options(channel) $options(match)
    }
  ]
  return [MakeSummary $options(interp) $tests]
}


proc xproc::runTestFiles {args} {
  array set options {channel stdout match {"*"} verbose 1 dir .}
  while {[llength $args]} {
    switch -glob -- [lindex $args 0] {
      -channel {set args [lassign $args - options(channel)]}
      -dir* {set args [lassign $args - options(dir)]}
      -match {set args [lassign $args - options(match)]}
      -verbose {set args [lassign $args - options(verbose)]}
      -*      {return -code error "unknown option: [lindex $args 0]"}
      default break
    }
  }
  if {[llength $args] > 0} {
    return -code error "invalid number of arguments"
  }

  set totalSummary [dict create total 0 passed 0 skipped 0 failed 0]
  set testFiles [GetTestFiles $options(dir)]
  set testFiles [lsort $testFiles]
  foreach file $testFiles {
    set summary [
      RunTestFile $options(dir) $file $options(match) \
                  $options(verbose) $options(channel)
    ]
    set totalSummary [SumDicts $totalSummary $summary]
  }
  return $totalSummary
}


proc xproc::descriptions {args} {
  variable descriptions
  array set options {match {"*"} interp {}}
  while {[llength $args]} {
    switch -glob -- [lindex $args 0] {
      -interp {set args [lassign $args - options(interp)]}
      -match {set args [lassign $args - options(match)]}
      -*      {return -code error "unknown option: [lindex $args 0]"}
      default break
    }
  }
  if {[llength $args] > 0} {
    return -code error "invalid number of arguments"
  }
  if {![interp exists $options(interp)]} {
    return -code error "interpreter doesn't exist: $options(interp)"
  }

  set lambdaVars [dict create match $options(match) interp $options(interp)]
  LFilter $lambdaVars $descriptions {{vars description} {
    set interp [dict get $description interp]
    set name [dict get $description name]
    if {[dict get $vars interp] ne $interp} {return false}
    MatchProcName [dict get $vars match] $name
  } xproc}
}


proc xproc::tests {args} {
  variable tests
  array set options {match {"*"} interp {}}
  while {[llength $args]} {
    switch -glob -- [lindex $args 0] {
      -interp {set args [lassign $args - options(interp)]}
      -match {set args [lassign $args - options(match)]}
      -*      {return -code error "unknown option: [lindex $args 0]"}
      default break
    }
  }
  if {[llength $args] > 0} {
    return -code error "invalid number of arguments"
  }
  if {![interp exists $options(interp)]} {
    return -code error "interpreter doesn't exist: $options(interp)"
  }

  set lambdaVars [dict create match $options(match) interp $options(interp)]
  LFilter $lambdaVars $tests {{vars test} {
    dict with test {
      if {[dict get $vars interp] ne $interp} {return false}
      MatchProcName [dict get $vars match] $name
    }
  } xproc}
}


proc xproc::testCases {args} {
  array set options {id 1}
  while {[llength $args]} {
    switch -glob -- [lindex $args 0] {
      -interp {set args [lassign $args - options(interp)]}
      --      {set args [lrange $args 1 end] ; break}
      -*      {return -code error "unknown option: [lindex $args 0]"}
      default break
    }
  }
  if {[llength $args] != 3} {
    return -code error "invalid number of arguments"
  }
  if {[info exists options(interp)] && ![interp exists $options(interp)]} {
    return -code error "interpreter doesn't exist: $options(interp)"
  }
  lassign $args testRun cases lambda
  set ns [TestRun ns $testRun]

  set i 0
  foreach case $cases {
    set returnCodes {ok return}
    if {[dict exists $case returnCodes]} {
      set returnCodes [dict get $case returnCodes]
    }
    set returnCodes [lmap code $returnCodes {ReturnCodeToValue $code}]
    try {
      if {[info exists options(interp)]} {
        set got [$options(interp) eval [list apply $lambda $ns $case]]
      } else {
        set got [uplevel 1 [list apply $lambda $ns $case]]
      }
      if {[dict exists $case result]} {
        set result [dict get $case result]
        if {$got ne $result} {
          fail $testRun "($i) got: $got, want: $result"
        }
      }
    } on error {got returnOptions} {
      if {[dict exists $case result]} {
        set result [dict get $case result]
        if {$got ne $result} {
          fail $testRun "($i) got: $got, want: $result"
        }
      } else {
        fail $testRun "($i) $got"
      }
      set returnCode [dict get $returnOptions -code]
      set wantCodeFound false
      foreach wantCode $returnCodes {
        if {$returnCode == $wantCode} {
          set wantCodeFound true
          break
        }
      }
      if {!$wantCodeFound} {
        fail $testRun \
            "($i) got return code: $returnCode, want one of: $returnCodes"
      }
    }
    incr i
  }
}


proc xproc::fail {testRun msg} {
  TestRun fail $testRun $msg
}



###########################
# Unexported commands
###########################

namespace eval xproc::TestRun {
  namespace export {[a-z]*}
  namespace ensemble create
  variable runs {}
  variable n 0
}

proc xproc::TestRun::new {name} {
  variable runs
  variable n
  dict set runs [incr n] [dict create failMessages {} name $name]
  return $n
}

proc xproc::TestRun::delete {testRun} {
  dict unset runs $testRun
}

proc xproc::TestRun::fail {testRun msg} {
  variable runs
  set oldFailMessages [dict get $runs $testRun failMessages]
  dict set runs $testRun failMessages [list {*}$oldFailMessages $msg]
}

proc xproc::TestRun::failMessages {testRun} {
  variable runs
  return [dict get $runs $testRun failMessages]
}

proc xproc::TestRun::hasFailed {testRun} {
  variable runs
  return [expr {[llength [dict get $runs $testRun failMessages]] > 0}]
}

proc xproc::TestRun::ns {testRun} {
  variable runs
  set name [dict get $runs $testRun name]
  return [namespace qualifiers $name]
}



proc xproc::RunTest {interp test verbose channel match} {
  dict set test skip false
  dict set test fail false
  set procName [dict get $test name]
  set ns [namespace qualifiers $procName]
  set id [dict get $test id]
  if {$interp ne [dict get $test interp]} {
    return $test
  }
  if {![MatchProcName $match $procName]} {
    dict set test skip true
    if {$verbose >= 2} {
      puts $channel "=== SKIP   $procName/$id"
    }
    return $test
  }

  set testRun [TestRun new $procName]
  if {$verbose >= 2} {
    puts $channel "=== RUN   $procName/$id"
  }
  set timeStart [clock microseconds]
  try {
    dict with test {
      if {$interp ne {}} {
        $interp eval [list apply $lambda $ns $testRun]
      } else {
        uplevel 1 [list apply $lambda $ns $testRun]
      }
    }
  } on error {result returnOptions} {
    set errorInfo [dict get $returnOptions -errorinfo]
    fail $testRun $errorInfo
  }
  set secondsElapsed [
    expr {([clock microseconds] - $timeStart)/1000000.}
  ]
  if {[TestRun hasFailed $testRun]} {
    if {$verbose >= 1} {
      puts $channel [
        format {--- FAIL  %s/%s (%0.2fs)} $procName $id $secondsElapsed
      ]
      foreach msg [TestRun failMessages $testRun] {
        puts $channel [IndentEachLine $msg 10 0]
      }
    }
  } else {
    if {$verbose >= 2} {
      puts $channel [
        format {--- PASS  %s/%s (%0.2fs)} $procName $id $secondsElapsed
      ]
    }
  }
  dict set test fail [TestRun hasFailed $testRun]
  TestRun delete $testRun
  return $test
}


proc xproc::TestExists {tests interp name id} {
  foreach test $tests {
    set testInterp [dict get $test interp]
    set testName [dict get $test name]
    set testID [dict get $test id]
    if {$testInterp eq $interp && $testName eq $name && $testID == $id} {
      return true
    }
  }
  return false
}


proc xproc::DescriptionExists {descriptions interp name} {
  foreach description $descriptions {
    set descriptionInterp [dict get $description interp]
    set descriptionName [dict get $description name]
    if {$descriptionInterp eq $interp && $descriptionName eq $name} {
      return true
    }
  }
  return false
}


proc xproc::GetTestFiles {dir} {
  set contentWalker [::fileutil::traverse %AUTO% [file normalize $dir]]
  set files {}
  $contentWalker foreach file {
    if {[file isfile $file] && [file extension $file] eq ".test"} {
      lappend files $file
    }
  }

  # Delete the contentWalker command because otherwise it can
  # be exported and confuses the tests
  rename $contentWalker ""
  return $files
}


xproc::proc xproc::FileWithoutDir {dir file} {
  set dirParts [file split [file normalize $dir]]
  set fileParts [file split [file normalize $file]]
  set numSame 0
  foreach dirPart $dirParts filePart $fileParts {
    if {$dirPart eq $filePart} {
      incr numSame
    } else {
      break
    }
  }
  file join {*}[lrange $fileParts $numSame end]
} -test {{ns t} {
  set cases [list \
    [dict create input [list [file join tmp a b] [file join tmp a b c]] \
                 result c] \
    [dict create input [list [file join tmp a b] [file join somewhere a b]] \
                 result [file join somewhere a b]] \
  ]

  xproc::testCases $t $cases {{ns case} {
    dict with case {${ns}::FileWithoutDir {*}$input}
  }}
}}


xproc::proc SumDicts {a b} {
  dict map {k v} $a {
    expr {$v + [dict get $b $k]}
  }
} -test {{ns t} {
  set cases {
    {input {{total 7 passed 3} {total 3 passed 4}}
     result {total 10 passed 7}}
    {input {{t 7 p 3 s 2} {t 3 p 4 s 1}}
     result {t 10 p 7 s 3}}
  }
  xproc::testCases $t $cases {{ns case} {
    dict with case {${ns}::SumDicts {*}$input}
  }}
}}


proc xproc::RunTestFile {dir file match verbose channel} {
  set timeStamp [clock format [clock seconds]]
  if {$verbose == 2} {
    puts $channel "\n[FileWithoutDir $dir $file]:  Began at $timeStamp"
  }
  set interp [interp create]
  if {$interp ne "stdout"} {interp transfer {} $channel $interp}
  try {
    $interp eval [list source $file]
    set summary [$interp eval [
      list xproc::runTests -verbose $verbose -channel $channel -match $match
    ]]
  } finally {
    if {$interp ne "stdout"} {interp transfer $interp $channel {}}
    interp delete $interp
    xproc::remove all -interp $interp
  }
  dict with summary {
    if {$verbose == 2} {
      puts $channel "[FileWithoutDir $dir $file]:  Ended at $timeStamp"
    }
    if {$verbose > 0} {
      puts -nonewline $channel "[FileWithoutDir $dir $file]:  "
      puts $channel \
        "Total: $total,  Passed: $passed,  Skipped: $skipped,  Failed: $failed"
    }
  }
  return $summary
}


xproc::proc xproc::LFilter {vars list lambda} {
  set result {}
  foreach e $list {
    if {[uplevel 1 [list apply $lambda $vars $e]]} {
      lappend result $e
    }
  }
  return $result
} -test {{ns t} {
  set cases {
    {input {{} {1 2 3 4} {{vars e} {expr {$e != 3}}}} result {1 2 4}}
    {input {{} {} {{vars e} {expr {$e != 3}}}} result {}}
    {input {{n 1} {1 2 3 4} {{vars e} {
      expr {$e != [dict get $vars n]}
    }}} result {2 3 4}}
  }
  xproc::testCases $t $cases {{ns case} {
    dict with case {${ns}::LFilter {*}$input}
  }}
}}


xproc::proc xproc::ReturnCodeToValue {code} {
  set returnCodeValues {ok 0 error 1 return 2 break 3 continue 4}
  if {[dict exists $returnCodeValues $code]} {
    return [dict get $returnCodeValues $code]
  }
  return $code
} -test {{ns t} {
  set cases {
    {input ok result 0}
    {input error result 1}
    {input return result 2}
    {input break result 3}
    {input continue result 4}
    {input fred result fred}
    {input 0 result 0}
    {input 7 result 7}
  }
  xproc::testCases $t $cases {{ns case} {
    dict with case {${ns}::ReturnCodeToValue $input}
  }}
}}


xproc::proc xproc::MakeSummary {interp tests} {
  set total 0
  set failed 0
  set skipped 0
  foreach test $tests {
    if {[dict get $test interp] eq $interp} {
      incr total
      if {[dict get $test fail]} {incr failed}
      if {[dict get $test skip]} {incr skipped}
    }
  }
  set passed [expr {($total-$failed)-$skipped}]
  return [
    dict create total $total passed $passed skipped $skipped failed $failed
  ]
} -test {{ns t} {
  set cases [list \
    [dict create input {{} {}} \
     result [dict create total 0 passed 0 skipped 0 failed 0]] \
    [dict create input {{} {{interp {} name name-1 id 0 skip false fail true}}} \
     result [dict create total 1 passed 0 skipped 0 failed 1]] \
    [dict create input {{} {{interp {} name name-1 id 0 skip false fail false}}} \
     result [dict create total 1 passed 1 skipped 0 failed 0]] \
    [dict create input {{} {{interp {} name name-1 id 0 skip false fail false} \
                        {interp {} name name-2 id 0 skip false fail false}}} \
     result [dict create total 2 passed 2 skipped 0 failed 0]] \
    [dict create input {{} {{interp {} name name-1 id 0 skip false fail true} \
                        {interp {} name name-2 id 0 skip false fail false}}} \
     result [dict create total 2 passed 1 skipped 0 failed 1]] \
    [dict create input {{} {{interp {} name name-1 id 0 skip false fail false} \
                        {interp {} name name-2 id 0 skip false fail true}}} \
     result [dict create total 2 passed 1 skipped 0 failed 1]] \
    [dict create input {{} {{interp {} name name-1 id 0 skip false fail true} \
                        {interp {} name name-2 id 0 skip false fail true}}} \
     result [dict create total 2 passed 0 skipped 0 failed 2]] \
    [dict create input {{} {{interp {} name name-1 id 0 skip true fail false} \
                        {interp {} name name-2 id 0 skip false fail true}}} \
     result [dict create total 2 passed 0 skipped 1 failed 1]] \
    [dict create input {{} {{interp {} name name-1 id 0 skip true fail false} \
                        {interp {} name name-2 id 0 skip true fail false}}} \
     result [dict create total 2 passed 0 skipped 2 failed 0]] \
    [dict create input {{} {{interp {} name name-1 id 0 skip true fail false} \
                        {interp {} name name-1 id 1 skip false fail true} \
                        {interp {} name name-2 id 0 skip true fail false} \
                        {interp {} name name-2 id 1 skip false fail false}}} \
     result [dict create total 4 passed 1 skipped 2 failed 1]] \
    [dict create input {{} {{interp {} name name-1 id 0 skip true fail false} \
                        {interp {} name name-1 id 1 skip false fail true} \
                        {interp interp1 name name-2 id 0 skip true fail false} \
                        {interp {} name name-2 id 1 skip false fail false}}} \
     result [dict create total 3 passed 1 skipped 1 failed 1]] \
    [dict create input {interp1 {{interp {} name name-1 id 0 skip true fail false} \
                        {interp {} name name-1 id 1 skip false fail true} \
                        {interp interp1 name name-2 id 0 skip true fail false} \
                        {interp {} name name-2 id 1 skip false fail false}}} \
     result [dict create total 1 passed 0 skipped 1 failed 0]] \
  ]
  xproc::testCases $t $cases {{ns case} {
    dict with case {${ns}::MakeSummary {*}$input}
  }}
}}


# Does procName match any of the patterns
xproc::proc xproc::MatchProcName {matchPatterns procName} {
  foreach matchPattern $matchPatterns {
    if {[string match $matchPattern $procName]} {return true}
  }
  return false
} -test {{ns t} {
  set cases {
    {input {{"*"} someName} result true}
    {input {{"*bob*" "*"} someName} result true}
    {input {{"*bob*" "*fred*"} someName} result false}
    {input {{"*bob*" "*fred*"} somebobName} result true}
    {input {{"*bob*" "*fred*"} somefredName} result true}
    {input {{"*bob*" "*fred*"} someharroldName} result false}
  }
  xproc::testCases $t $cases {{ns case} {
    dict with case {${ns}::MatchProcName {*}$input}
  }}
}}


xproc::proc xproc::IndentEachLine {text numSpaces ignoreLines} {
  set lines [split $text "\n"]
  set indentedLines {}
  set i 0
  foreach line $lines {
    if {$i < $ignoreLines || $line eq ""} {
      lappend indentedLines $line
    } else {

      lappend indentedLines "[string repeat " " $numSpaces]$line"
    }
    incr i
  }
  return [join $indentedLines "\n"]
} -test {{ns t} {
  set text {this is some text
and a little more

and some more here
    this has some more
 and a little less indented}
  set want {this is some text
          and a little more

          and some more here
              this has some more
           and a little less indented}
  set got [${ns}::IndentEachLine $text 10 1]
  if {$got ne $want} {
    xproc::fail $t "got: $got, want: $want"
  }
}}


xproc::proc xproc::CountIndent {line} {
  set count 0
  for {set i 0} {$i < [string length $line]} {incr i} {
    if {[string index $line $i] eq " "} {
      incr count
    } else {
      break
    }
  }
  return $count
} -test {{ns t} {
  set cases {
    {input {hello this is some text} result 0}
    {input {  hello this is some text} result 2}
    {input {  hello this is some text   } result 2}
    {input {    hello this is some text } result 4}
  }
  xproc::testCases $t $cases {{ns case} {
    dict with case {${ns}::CountIndent $input}
  }}
}}


xproc::proc xproc::StripIndent {lines numSpaces} {
  set newLines [list]
  foreach line $lines {
    for {set i 0} {$i < [string length $line] && $i < $numSpaces} {incr i} {
      if {[string index $line $i] ne " "} {break}
    }
    lappend newLines [string range $line $i end]
  }
  return $newLines
} -test {{ns t} {
  set cases {
    {input {
      { "hello some text"
        " some more text"
        "and a little more"
        "   guess what"
      } 0} result {
        "hello some text"
        " some more text"
        "and a little more"
        "   guess what"
      }}
    {input {
      { "hello some text"
        " some more text"
        "and a little more"
        "   guess what"
      } 1} result {
        "hello some text"
        "some more text"
        "and a little more"
        "  guess what"
      }}
    {input {
      { "hello some text"
        " some more text"
        "and a little more"
        "   guess what"
      } 2} result {
        "hello some text"
        "some more text"
        "and a little more"
        " guess what"
      }}
    {input {
      { "hello some text"
        " some more text"
        "and a little more"
        "   guess what"
      } 3} result {
        "hello some text"
        "some more text"
        "and a little more"
        "guess what"
      }}
  }
  set i 0
  foreach c $cases {
    dict with c {
      set got [${ns}::StripIndent {*}$input]
      if {[llength $got] != [llength $result]} {
        xproc::fail $t "($i) got: $got, want: $result"
      } else {
        foreach g $got w $result {
          if {$g ne $w} {
            xproc::fail $t "($i) got: $got, want: $result"
            break
          }
        }
      }
    }
    incr i
  }
}}


xproc::proc xproc::TidyDescription {description} {
  set description [string trimright $description]
  set lines [split $description "\n"]

  # Strip first newlines
  set lineNum 0
  foreach line $lines {
    if {[string trim $line] ne ""} {break}
    incr lineNum
  }
  set lines [lrange $lines $lineNum end]
  set normalIndent [CountIndent [lindex $lines 0]]
  set lines [StripIndent $lines $normalIndent]
  return [join $lines "\n"]
} -test {{ns t} {
  set cases {
    { input {this is a description}
      result {this is a description}}
    { input {
        this is a description
      }
      result {this is a description}}
    { input {
        this is a description

        this is some more text on another
        line to see if everything is aligned properly
          this text is indent further

          as is this line
            even futher down here
      }
      result {this is a description

this is some more text on another
line to see if everything is aligned properly
  this text is indent further

  as is this line
    even futher down here}}
    { input {this is a description without a leading newline

        this is some more text on another
        line to see if everything is aligned properly
      }
      result {this is a description without a leading newline

        this is some more text on another
        line to see if everything is aligned properly}}
  }

  xproc::testCases $t $cases {{ns case} {
    dict with case {${ns}::TidyDescription $input}
  }}
}}




##################################################
# Descriptions for exported procedures
##################################################

xproc::describe xproc::proc {
  Create a Tcl procedure, like ::proc, but extended with extra switches

  xproc::proc name args body ?switches?

  This extendeds ::proc by adding the following switches:
    -description description   Records the given description
    -interp path               Creates the procedure in interpreter path.
                               The default is the current interpreter.
    -test lambda               Records the given lambda to be used
                               to test this procedure.

  The test lambda has two parameters:
    ns        The namespace qualifiers of the procedure being tested
    testRun   The testRun object which identifies this test
}

xproc::describe xproc::remove {
  Remove xproc functionality from procedures

  xproc::remove type ?-interp path? ?-match patternList?

  The type can be one of:
    tests           Remove tests
    descriptions    Remove descriptions
    all             Remove all xproc functionality

  The switches do the following:
    -interp path          Select only the procedures in interpreter path.
                          The default is the current interpreter.
    -match patternList    Matches procedureNames against patterns in
                          patternList, the default is {"*"}
}

xproc::describe xproc::testCases {
  Test the supplied test cases within a test lambda

  xproc::testCases ?switches? testRun cases lambda

  The switches do the following:
    -interp path   Creates the test for a procedure in interpreter path.
                   The default is the current interpreter.
    --             Marks the end of switches

  The testRun is passed through a test lambda defined with xproc::test
  or using -test with xproc::proc.

  The cases are a list of dictionaries that describe each test case with
  the following keys:
    input        The value to pass to the lambda
    result       The value to test against the result of the lambda
    returnCodes  Return codes to test against, the default is {ok return}
  Extra keys may be present and therefore passed to the lambda.

  The lambda has two parameters:
    ns        The namespace qualifiers of the procedure being tested
    case      The test case described above
}


xproc::describe xproc::fail {
  Output a FAIL message and record that test has failed

  xproc::fail testRun msg

  This is to be called within a test lambda.
}


xproc::describe xproc::test {
  Record the given lambda to test a procedure

  xproc::test ?switches? procedureName lambda

  The switches do the following:
    -id id         Give an id to the test to allow multiple tests
                   for a procedureName.  The default is 1.
    -interp path   Creates the test for a procedure in interpreter path.
                   The default is the current interpreter.
    --             Marks the end of switches

  The test lambda has two parameters:
    ns        The namespace qualifiers of the procedure being tested
    testRun   The testRun object which identifies this test
}

xproc::describe xproc::describe {
  Record the given description for a procedure

  xproc::describe ?switches? procedureName description

  The switches do the following:
    -interp path   Creates the description for a procedure in interpreter
                   path.  The default is the current interpreter.
    --             Marks the end of switches

  A description shouldn't contain tabs as it will cause text
  alignment issues.
}

xproc::describe xproc::runTests {
  Run the tests recorded using xproc

  xproc::runTests ?switches?

  The switches do the following:
    -channel channelID    A channel to send output to. The default is stdout.
    -interp path          Creates the test for a procedure in interpreter
                          path.  The default is the current interpreter.
    -match patternList    Matches procedureNames against patterns in
                          patternList, the default is {"*"}
    -verbose level        Controls the level of output to stdout:
                            0  None
                            1  Failing tests
                            2  All tests
                          The default is 1
}

xproc::describe xproc::runTestFiles {
  Load and run test files

  xproc::runTests ?switches?

  The switches do the following:
    -channel channelID    A channel to send output to. The default is stdout.
    -dir directory        The directory to start running the *.test files
    -match patternList    Matches procedureNames against patterns in
                          patternList.  The default is {"*"}
    -verbose level        Controls the level of output to stdout:
                            0  None
                            1  Failing tests
                            2  All tests
                          The default is 1
}


xproc::describe xproc::descriptions {
  Return the descriptions recorded using xproc

  xproc::descriptions ?-interp path? ?-match patternList?

  The switches do the following:
    -interp path          Select only the description for procedures
                          in interpreter path.
                          The default is the current interpreter.
    -match patternList    Matches procedureNames against patterns in
                          patternList, the default is {"*"}

  The return value is a list of descriptions.  Each discription is a
  dictionary with at least the following keys:
    interp        The interpreter within which the procedure exists
                  that is being described
    name          The full name of the procedure described
    description   The description of the procedure
}

xproc::describe xproc::tests {
  Return the tests recorded using xproc

  xproc::tests ?switches?

  The switches do the following:
    -interp path          Select only the tests for procedures
                          in interpreter path.
                          The default is the current interpreter.
    -match patternList    Matches procedureNames against patterns in
                          patternList, the default is {"*"}

  The return value is a list of tests.  Each test is a dictionary
  containing at least the following keys:
    interp        The interpreter within which the procedure exists
                  that is being tested
    name          The full name of the procedure being tested
    id            The ID number of the test for the specified procedure
}
